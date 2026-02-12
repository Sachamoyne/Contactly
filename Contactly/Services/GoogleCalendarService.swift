import Foundation
import GoogleSignIn
import GoogleSignInSwift
import Observation
import Security
import UIKit

@Observable
@MainActor
final class GoogleCalendarService {
    private let scope = "https://www.googleapis.com/auth/calendar.readonly"
    private let tokenStore = GoogleTokenStore()
    private static let cachedEventsFilename = "google_calendar_events.json"

    private(set) var isSignedIn = false
    private(set) var accountEmail = ""
    private(set) var cachedEvents: [CalendarEvent] = []

    init() {
        cachedEvents = Self.loadCachedEvents()
        Task { [weak self] in
            await self?.restoreSessionIfPossible()
        }
    }

    func signIn() async throws {
        let clientID = try validatedClientID()
        try validateURLScheme(for: clientID)

        guard let presenter = Self.topViewController() else {
            throw GoogleCalendarServiceError.missingPresenter
        }

        let result: GIDSignInResult = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GIDSignInResult, Error>) in
            GIDSignIn.sharedInstance.signIn(
                withPresenting: presenter,
                hint: nil,
                additionalScopes: [scope]
            ) { signInResult, error in
                if let error {
                    continuation.resume(throwing: GoogleCalendarServiceError.oauthFailure(error.localizedDescription))
                    return
                }

                guard let signInResult else {
                    continuation.resume(throwing: GoogleCalendarServiceError.oauthFailure("No sign-in result returned."))
                    return
                }

                continuation.resume(returning: signInResult)
            }
        }

        guard !result.user.accessToken.tokenString.isEmpty else {
            throw GoogleCalendarServiceError.tokenMissing
        }

        let token = result.user.accessToken.tokenString
        tokenStore.save(token)
        isSignedIn = true
        accountEmail = result.user.profile?.email ?? ""

        _ = try await fetchUpcomingEvents()
    }

    func reconnect() async throws {
        try await signIn()
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        tokenStore.clear()
        isSignedIn = false
        accountEmail = ""
    }

    func fetchUpcomingEvents(from startDate: Date = Date(), daysAhead: Int = 1) async throws -> [CalendarEvent] {
        let payload = try await requestGoogleEventsPayload(from: startDate, daysAhead: daysAhead)
        let events = payload.items.compactMap(mapGoogleEvent)
        cache(events)
        return events
    }

    func fetchUpcomingSyncedEvents(from startDate: Date = Date(), daysAhead: Int = 1) async throws -> [SyncedCalendarEvent] {
        let payload = try await requestGoogleEventsPayload(from: startDate, daysAhead: daysAhead)
        return payload.items.compactMap(mapGoogleSyncedEvent)
    }

    private func requestGoogleEventsPayload(from startDate: Date, daysAhead: Int) async throws -> GoogleCalendarEventsResponse {
        let accessToken = try await validAccessToken()

        do {
            return try await requestEventsPayload(
                accessToken: accessToken,
                startDate: startDate,
                daysAhead: daysAhead
            )
        } catch GoogleCalendarServiceError.unauthorized {
            guard let refreshedToken = try await refreshAccessTokenSilently() else {
                throw GoogleCalendarServiceError.unauthorized
            }

            return try await requestEventsPayload(
                accessToken: refreshedToken,
                startDate: startDate,
                daysAhead: daysAhead
            )
        }
    }

    private func requestEventsPayload(accessToken: String, startDate: Date, daysAhead: Int) async throws -> GoogleCalendarEventsResponse {
        let endDate = Calendar.current.date(byAdding: .day, value: daysAhead, to: startDate) ?? startDate
        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        components?.queryItems = [
            URLQueryItem(name: "timeMin", value: formatter.string(from: startDate)),
            URLQueryItem(name: "timeMax", value: formatter.string(from: endDate)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "250"),
            URLQueryItem(name: "fields", value: "items(id,summary,location,start,end,attendees(email,self))")
        ]

        guard let url = components?.url else {
            throw GoogleCalendarServiceError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCalendarServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw GoogleCalendarServiceError.unauthorized
            }
            throw GoogleCalendarServiceError.apiFailure(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(GoogleCalendarEventsResponse.self, from: data)
    }

    private func restoreSessionIfPossible() async {
        guard GIDSignIn.sharedInstance.hasPreviousSignIn() else {
            isSignedIn = tokenStore.read() != nil
            return
        }

        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            let token = user.accessToken.tokenString
            guard !token.isEmpty else {
                throw GoogleCalendarServiceError.tokenMissing
            }

            tokenStore.save(token)
            isSignedIn = true
            accountEmail = user.profile?.email ?? ""
        } catch {
            isSignedIn = tokenStore.read() != nil
        }
    }

    private func validAccessToken() async throws -> String {
        if let user = GIDSignIn.sharedInstance.currentUser {
            do {
                let refreshedUser = try await user.refreshTokensIfNeeded()
                let token = refreshedUser.accessToken.tokenString
                guard !token.isEmpty else {
                    throw GoogleCalendarServiceError.tokenMissing
                }

                tokenStore.save(token)
                isSignedIn = true
                accountEmail = refreshedUser.profile?.email ?? ""
                return token
            } catch {
                tokenStore.clear()
                isSignedIn = false
                accountEmail = ""
            }
        }

        if let cached = tokenStore.read(), !cached.isEmpty {
            isSignedIn = true
            return cached
        }

        throw GoogleCalendarServiceError.notSignedIn
    }

    private func refreshAccessTokenSilently() async throws -> String? {
        if let user = GIDSignIn.sharedInstance.currentUser {
            do {
                let refreshed = try await user.refreshTokensIfNeeded()
                let token = refreshed.accessToken.tokenString
                guard !token.isEmpty else {
                    return nil
                }
                tokenStore.save(token)
                isSignedIn = true
                accountEmail = refreshed.profile?.email ?? ""
                return token
            } catch {
                tokenStore.clear()
            }
        }

        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            do {
                let restored = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
                let token = restored.accessToken.tokenString
                guard !token.isEmpty else {
                    return nil
                }
                tokenStore.save(token)
                isSignedIn = true
                accountEmail = restored.profile?.email ?? ""
                return token
            } catch {
                tokenStore.clear()
            }
        }

        isSignedIn = false
        accountEmail = ""
        return nil
    }

    private func validatedClientID() throws -> String {
        if let configured = GIDSignIn.sharedInstance.configuration?.clientID,
           !configured.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return configured
        }

        if let plistClientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
           !plistClientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return plistClientID
        }

        throw GoogleCalendarServiceError.missingClientID
    }

    private func validateURLScheme(for clientID: String) throws {
        let suffix = ".apps.googleusercontent.com"
        guard clientID.hasSuffix(suffix) else {
            throw GoogleCalendarServiceError.invalidClientID
        }

        let prefix = String(clientID.dropLast(suffix.count))
        let expectedScheme = "com.googleusercontent.apps.\(prefix)"

        guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            throw GoogleCalendarServiceError.missingURLScheme(expectedScheme)
        }

        let schemes = urlTypes
            .compactMap { $0["CFBundleURLSchemes"] as? [String] }
            .flatMap { $0 }

        if !schemes.contains(expectedScheme) {
            throw GoogleCalendarServiceError.missingURLScheme(expectedScheme)
        }
    }

    private func mapGoogleEvent(_ event: GoogleCalendarEvent) -> CalendarEvent? {
        guard let start = parsedDate(from: event.start) else { return nil }

        let end = parsedDate(from: event.end)
            ?? Calendar.current.date(byAdding: .hour, value: 1, to: start)
            ?? start

        let title = event.summary?.trimmingCharacters(in: .whitespacesAndNewlines)
        return CalendarEvent(
            title: (title?.isEmpty == false ? title : nil) ?? "(No Title)",
            startDate: start,
            endDate: end,
            location: event.location ?? ""
        )
    }

    private func mapGoogleSyncedEvent(_ event: GoogleCalendarEvent) -> SyncedCalendarEvent? {
        guard let start = parsedDate(from: event.start) else { return nil }

        let end = parsedDate(from: event.end)
            ?? Calendar.current.date(byAdding: .hour, value: 1, to: start)
            ?? start

        let titleValue = event.summary?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = (titleValue?.isEmpty == false ? titleValue : nil) ?? "Meeting"

        let attendeeEmails: [String] = (event.attendees ?? [])
            .compactMap { (attendee: GoogleCalendarAttendee) -> String? in
                guard let email = attendee.email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !email.isEmpty else {
                    return nil
                }
                return email
            }

        return SyncedCalendarEvent(
            id: event.id ?? UUID().uuidString,
            title: title,
            startDate: start,
            endDate: end,
            attendeeEmails: Array(Set(attendeeEmails)).sorted()
        )
    }

    private func parsedDate(from container: GoogleCalendarEventDate?) -> Date? {
        guard let container else { return nil }

        if let dateTime = container.dateTime {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let parsed = iso.date(from: dateTime) {
                return parsed
            }

            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            if let parsed = fallback.date(from: dateTime) {
                return parsed
            }
        }

        if let dateOnly = container.date {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            if let parsed = formatter.date(from: dateOnly) {
                return parsed
            }
        }

        return nil
    }

    private func cache(_ events: [CalendarEvent]) {
        cachedEvents = events
        try? PersistenceStore.save(events, to: Self.cachedEventsFilename)
    }

    private static func loadCachedEvents() -> [CalendarEvent] {
        guard PersistenceStore.exists(cachedEventsFilename) else {
            return []
        }
        return (try? PersistenceStore.load([CalendarEvent].self, from: cachedEventsFilename)) ?? []
    }

    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let root = base
            ?? (UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?
                .rootViewController)

        if let navigation = root as? UINavigationController {
            return topViewController(base: navigation.visibleViewController)
        }

        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }

        if let presented = root?.presentedViewController {
            return topViewController(base: presented)
        }

        return root
    }
}

enum GoogleCalendarServiceError: LocalizedError {
    case missingPresenter
    case missingClientID
    case invalidClientID
    case missingURLScheme(String)
    case oauthFailure(String)
    case tokenMissing
    case notSignedIn
    case invalidRequest
    case invalidResponse
    case unauthorized
    case apiFailure(Int)

    var errorDescription: String? {
        switch self {
        case .missingPresenter:
            return "Unable to start Google sign-in from the current screen."
        case .missingClientID:
            return "Google Sign-In is misconfigured: GIDClientID is missing from Info.plist."
        case .invalidClientID:
            return "Google Sign-In is misconfigured: GIDClientID format is invalid."
        case let .missingURLScheme(expected):
            return "Google Sign-In is misconfigured: missing URL scheme \(expected) in Info.plist."
        case let .oauthFailure(reason):
            return "Google OAuth error: \(reason)"
        case .tokenMissing:
            return "Google sign-in completed but no access token was returned."
        case .notSignedIn:
            return "Google account is not connected."
        case .invalidRequest:
            return "Unable to prepare Google Calendar request."
        case .invalidResponse:
            return "Google Calendar returned an invalid response."
        case .unauthorized:
            return "Google session expired. Please reconnect your account."
        case let .apiFailure(code):
            return "Google Calendar API failed with status code \(code)."
        }
    }
}

private struct GoogleCalendarEventsResponse: Decodable {
    let items: [GoogleCalendarEvent]
}

private struct GoogleCalendarEvent: Decodable {
    let id: String?
    let summary: String?
    let location: String?
    let start: GoogleCalendarEventDate?
    let end: GoogleCalendarEventDate?
    let attendees: [GoogleCalendarAttendee]?
}

private struct GoogleCalendarAttendee: Decodable {
    let email: String?
    let `self`: Bool?
}

private struct GoogleCalendarEventDate: Decodable {
    let dateTime: String?
    let date: String?
}

private struct GoogleTokenStore {
    private let service = "com.sacha.Contactly"
    private let account = "google_calendar_access_token"

    func save(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)

        var newItem = query
        newItem[kSecValueData as String] = data
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        SecItemAdd(newItem as CFDictionary, nil)
    }

    func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}
