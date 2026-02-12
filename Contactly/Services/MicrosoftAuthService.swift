import Foundation
import MSAL
import Observation
import Security
import UIKit

@Observable
@MainActor
final class MicrosoftAuthService {
    private let scope = "Calendars.Read"
    private let tokenStore = MicrosoftTokenStore()

    private(set) var isSignedIn = false
    private(set) var accountEmail = ""

    private let application: MSALPublicClientApplication?

    init() {
        application = try? MicrosoftAuthService.buildApplication()
        if let token = tokenStore.read(), !token.isEmpty {
            isSignedIn = true
        }
    }

    func signIn() async throws {
        guard let application else {
            throw MicrosoftAuthError.missingConfiguration
        }

        guard let presenter = Self.topViewController() else {
            throw MicrosoftAuthError.missingPresenter
        }

        let webParameters = MSALWebviewParameters(authPresentationViewController: presenter)
        let parameters = MSALInteractiveTokenParameters(scopes: [scope], webviewParameters: webParameters)

        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MSALResult, Error>) in
            application.acquireToken(with: parameters) { result, error in
                if let error {
                    continuation.resume(throwing: MicrosoftAuthError.oauth(error.localizedDescription))
                    return
                }
                guard let result else {
                    continuation.resume(throwing: MicrosoftAuthError.oauth("No result returned from Microsoft sign-in."))
                    return
                }
                continuation.resume(returning: result)
            }
        }

        let token = result.accessToken
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MicrosoftAuthError.tokenMissing
        }

        tokenStore.save(token)
        isSignedIn = true
        accountEmail = result.account.username ?? ""
    }

    func signOut() async {
        guard let application else {
            tokenStore.clear()
            isSignedIn = false
            accountEmail = ""
            return
        }

        let accounts = allAccounts(application: application)

        for account in accounts {
            try? application.remove(account)
        }

        tokenStore.clear()
        isSignedIn = false
        accountEmail = ""
    }

    func acquireToken() async throws -> String {
        guard let application else {
            throw MicrosoftAuthError.missingConfiguration
        }

        if let token = try await acquireTokenSilently(application: application) {
            return token
        }

        try await signIn()

        guard let token = tokenStore.read(), !token.isEmpty else {
            throw MicrosoftAuthError.tokenMissing
        }

        return token
    }

    func handleRedirectURL(_ url: URL) -> Bool {
        MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: nil)
    }

    private func acquireTokenSilently(application: MSALPublicClientApplication) async throws -> String? {
        let accounts = allAccounts(application: application)
        guard let account = accounts.first else {
            return tokenStore.read()
        }

        let parameters = MSALSilentTokenParameters(scopes: [scope], account: account)

        do {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MSALResult, Error>) in
                application.acquireTokenSilent(with: parameters) { result, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let result else {
                        continuation.resume(throwing: MicrosoftAuthError.tokenMissing)
                        return
                    }

                    continuation.resume(returning: result)
                }
            }

            let token = result.accessToken
            guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw MicrosoftAuthError.tokenMissing
            }

            tokenStore.save(token)
            isSignedIn = true
            accountEmail = result.account.username ?? ""
            return token
        } catch {
            return tokenStore.read()
        }
    }

    private func allAccounts(application: MSALPublicClientApplication) -> [MSALAccount] {
        do {
            return try application.allAccounts()
        } catch {
            return []
        }
    }

    private static func buildApplication() throws -> MSALPublicClientApplication {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "MSALClientID") as? String,
              !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MicrosoftAuthError.missingConfiguration
        }

        guard let redirectURI = Bundle.main.object(forInfoDictionaryKey: "MSALRedirectURI") as? String,
              !redirectURI.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MicrosoftAuthError.missingConfiguration
        }

        guard let authorityURL = URL(string: "https://login.microsoftonline.com/common") else {
            throw MicrosoftAuthError.missingConfiguration
        }

        let authority = try MSALAADAuthority(url: authorityURL)

        let config = MSALPublicClientApplicationConfig(
            clientId: clientID,
            redirectUri: redirectURI,
            authority: authority
        )

        return try MSALPublicClientApplication(configuration: config)
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

enum MicrosoftAuthError: LocalizedError {
    case missingConfiguration
    case missingPresenter
    case oauth(String)
    case tokenMissing

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Microsoft authentication is not configured correctly in Info.plist."
        case .missingPresenter:
            return "Unable to start Microsoft sign-in from the current screen."
        case let .oauth(message):
            return "Microsoft sign-in error: \(message)"
        case .tokenMissing:
            return "Microsoft authentication completed but no token was returned."
        }
    }
}

private struct MicrosoftTokenStore {
    private let service = "com.sacha.Contactly"
    private let account = "microsoft_calendar_access_token"

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
