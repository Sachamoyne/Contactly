import Foundation
import Observation

@Observable
@MainActor
final class OutlookCalendarService {
    private let authService: MicrosoftAuthService

    init(authService: MicrosoftAuthService) {
        self.authService = authService
    }

    func fetchUpcomingSyncedEvents(from startDate: Date = Date(), daysAhead: Int = 1) async throws -> [SyncedCalendarEvent] {
        let token = try await authService.acquireToken()

        let endDate = Calendar.current.date(byAdding: .day, value: daysAhead, to: startDate) ?? startDate

        var components = URLComponents(string: "https://graph.microsoft.com/v1.0/me/events")
        components?.queryItems = [
            URLQueryItem(name: "$select", value: "id,subject,start,end,attendees,location,isAllDay"),
            URLQueryItem(name: "$orderby", value: "start/dateTime"),
            URLQueryItem(name: "$top", value: "250"),
            URLQueryItem(name: "$filter", value: graphFilter(from: startDate, to: endDate))
        ]

        guard let url = components?.url else {
            throw OutlookCalendarError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OutlookCalendarError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw OutlookCalendarError.unauthorized
            }
            throw OutlookCalendarError.apiFailure(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let payload = try decoder.decode(OutlookEventsResponse.self, from: data)

        return payload.value.compactMap { event in
            guard let start = parseGraphDate(event.start) else { return nil }
            let end = parseGraphDate(event.end) ?? Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? start

            let attendeeEmails = (event.attendees ?? [])
                .compactMap { attendee -> String? in
                    guard let address = attendee.emailAddress?.address?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                          !address.isEmpty else {
                        return nil
                    }
                    return address
                }

            return SyncedCalendarEvent(
                id: event.id,
                title: event.subject?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? event.subject ?? "Meeting"
                    : "Meeting",
                startDate: start,
                endDate: end,
                attendeeEmails: Array(Set(attendeeEmails)).sorted()
            )
        }
    }

    func fetchUpcomingEvents(from startDate: Date = Date(), daysAhead: Int = 1) async throws -> [CalendarEvent] {
        let syncedEvents = try await fetchUpcomingSyncedEvents(from: startDate, daysAhead: daysAhead)
        return syncedEvents.map { event in
            CalendarEvent(
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate
            )
        }
    }

    private func graphFilter(from startDate: Date, to endDate: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return "start/dateTime ge '\(formatter.string(from: startDate))' and start/dateTime le '\(formatter.string(from: endDate))'"
    }

    private func parseGraphDate(_ value: OutlookDateTime?) -> Date? {
        guard let value else { return nil }
        let trimmed = value.dateTime.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let isoWithFraction = ISO8601DateFormatter()
        isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = isoWithFraction.date(from: trimmed) {
            return parsed
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let parsed = iso.date(from: trimmed) {
            return parsed
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        if let timezone = TimeZone(identifier: value.timeZone) {
            formatter.timeZone = timezone
        } else {
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
        }

        return formatter.date(from: trimmed)
    }
}

enum OutlookCalendarError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case unauthorized
    case apiFailure(Int)

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Unable to prepare Outlook Calendar request."
        case .invalidResponse:
            return "Outlook Calendar returned an invalid response."
        case .unauthorized:
            return "Outlook session expired. Please reconnect your account."
        case let .apiFailure(code):
            return "Outlook Calendar API failed with status code \(code)."
        }
    }
}

private struct OutlookEventsResponse: Decodable {
    let value: [OutlookEvent]
}

private struct OutlookEvent: Decodable {
    let id: String
    let subject: String?
    let start: OutlookDateTime?
    let end: OutlookDateTime?
    let attendees: [OutlookAttendee]?
}

private struct OutlookDateTime: Decodable {
    let dateTime: String
    let timeZone: String
}

private struct OutlookAttendee: Decodable {
    let emailAddress: OutlookEmailAddress?
}

private struct OutlookEmailAddress: Decodable {
    let address: String?
}
