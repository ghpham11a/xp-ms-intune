//
//  AuthManager.swift
//  IOSIntuneApp
//
//  Created by Anthony Pham on 4/16/26.
//

import Foundation
import UIKit
import MSAL
import IntuneMAMSwift

enum AuthError: LocalizedError {
    case msalNotConfigured
    case noPresentingViewController
    case missingResult

    var errorDescription: String? {
        switch self {
        case .msalNotConfigured: "MSAL is not configured."
        case .noPresentingViewController: "No foreground window to present sign-in."
        case .missingResult: "Sign-in returned no result."
        }
    }
}

@MainActor
@Observable
final class AuthManager {

    var userUPN: String?
    var isEnrolled = false
    var enrollmentStatus = "Not started"
    var isLoading = false
    var errorMessage: String?
    var mamAppConfig: [(key: String, value: String)] = []

    private var msalApp: MSALPublicClientApplication?

    private let clientId = Bundle.main.intuneMAMSetting(for: "ADALClientId") ?? ""
    private let authorityURL = Bundle.main.intuneMAMSetting(for: "ADALAuthority") ?? ""
    private let redirectUri = Bundle.main.intuneMAMSetting(for: "ADALRedirectUri") ?? ""

    init() {
        setupMSAL()
        observeEnrollmentNotifications()
        observeAppConfigNotifications()
        restoreEnrolledState()
    }

    private func restoreEnrolledState() {
        guard let enrolledId = IntuneMAMEnrollmentManager.instance().enrolledAccountId(),
              !enrolledId.isEmpty else { return }
        let cached = (try? msalApp?.allAccounts())?.first
        userUPN = cached?.username ?? enrolledId
        isEnrolled = true
        enrollmentStatus = "✅ Enrolled — policies active"
        refreshMAMAppConfig()
        print("♻️ Restored enrolled state for \(enrolledId)")
    }

    private func refreshMAMAppConfig() {
        guard let accountId = IntuneMAMEnrollmentManager.instance().enrolledAccountId() else {
            mamAppConfig = []
            return
        }
        let config = IntuneMAMAppConfigManager.instance().appConfig(forAccountId: accountId)
        let dicts = config.fullData ?? []

        var merged: [String: [String]] = [:]
        for dict in dicts {
            for (rawKey, rawValue) in dict {
                guard let key = rawKey as? String else { continue }
                merged[key, default: []].append(String(describing: rawValue))
            }
        }
        mamAppConfig = merged.keys.sorted().map { key in
            (key, merged[key]!.joined(separator: ", "))
        }
        print("🧩 MAM app config refreshed — \(mamAppConfig.count) key(s)")
    }

    private func observeAppConfigNotifications() {
        let name = Notification.Name("IntuneMAMAppConfigDidChangeNotification")
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: name) {
                guard let self else { return }
                self.refreshMAMAppConfig()
            }
        }
    }

    // MARK: - Setup

    private func setupMSAL() {
        print("MSAL setup — clientId=\(clientId) authority=\(authorityURL) redirect=\(redirectUri)")
        guard let url = URL(string: authorityURL) else {
            errorMessage = "Invalid ADALAuthority URL in Info.plist"
            return
        }
        do {
            let authority = try MSALAADAuthority(url: url)
            let config = MSALPublicClientApplicationConfig(
                clientId: clientId,
                redirectUri: redirectUri,
                authority: authority
            )
            config.cacheConfig.keychainSharingGroup = "com.microsoft.adalcache"
            msalApp = try MSALPublicClientApplication(configuration: config)
            print("✅ MSAL configured")
        } catch let nsError as NSError {
            let reason = nsError.userInfo["MSALErrorDescriptionKey"] as? String
                ?? nsError.localizedDescription
            errorMessage = "MSAL setup failed (\(nsError.domain) \(nsError.code)): \(reason)"
            print("❌ MSAL setup error: \(nsError)\nuserInfo: \(nsError.userInfo)")
        }
    }

    // MARK: - Sign In

    func signIn() async {
        isLoading = true
        errorMessage = nil
        enrollmentStatus = "Signing in..."
        defer { isLoading = false }

        do {
            let account = try await acquireToken()
            let upn = account.username ?? ""
            let objectId = account.homeAccountId?.objectId ?? ""
            let fullId = account.identifier ?? ""
            userUPN = upn
            print("👤 signed in — upn=\(upn) objectId=\(objectId) fullId=\(fullId)")
            let cachedAccounts = (try? msalApp?.allAccounts()) ?? []
            print("🔑 MSAL cache holds \(cachedAccounts.count) account(s): \(cachedAccounts.map { $0.username ?? "?" })")

            if let enrolledId = IntuneMAMEnrollmentManager.instance().enrolledAccountId(),
               !enrolledId.isEmpty {
                isEnrolled = true
                enrollmentStatus = "✅ Enrolled — policies active"
                refreshMAMAppConfig()
                print("♻️ Already enrolled as \(enrolledId) — skipping enroll call")
                return
            }

            enrollmentStatus = "Enrolling with Intune..."
            IntuneMAMEnrollmentManager.instance().registerAndEnrollAccountId(objectId)
        } catch {
            errorMessage = error.localizedDescription
            enrollmentStatus = "Sign in failed"
        }
    }

    private func acquireToken() async throws -> MSALAccount {
        guard let msalApp else { throw AuthError.msalNotConfigured }

        if let cached = (try? msalApp.allAccounts())?.first,
           let result = try? await acquireTokenSilent(app: msalApp, account: cached) {
            print("🔓 silent token acquired for \(cached.username ?? "?")")
            return result.account
        }

        return try await acquireTokenInteractive(app: msalApp).account
    }

    private func acquireTokenSilent(app: MSALPublicClientApplication, account: MSALAccount) async throws -> MSALResult {
        let params = MSALSilentTokenParameters(scopes: ["user.read"], account: account)
        return try await withCheckedThrowingContinuation { continuation in
            app.acquireTokenSilent(with: params) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: AuthError.missingResult)
                }
            }
        }
    }

    private func acquireTokenInteractive(app: MSALPublicClientApplication) async throws -> MSALResult {
        let rootVC = try presentingViewController()
        let params = MSALInteractiveTokenParameters(
            scopes: ["user.read"],
            webviewParameters: MSALWebviewParameters(authPresentationViewController: rootVC)
        )
        params.promptType = .selectAccount

        return try await withCheckedThrowingContinuation { continuation in
            app.acquireToken(with: params) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: AuthError.missingResult)
                }
            }
        }
    }

    // MARK: - Sign Out

    func signOut() {
        guard let msalApp else { return }

        if let accountId = IntuneMAMEnrollmentManager.instance().enrolledAccountId() {
            IntuneMAMEnrollmentManager.instance().deRegisterAndUnenrollAccountId(accountId, withWipe: false)
        }

        do {
            for account in try msalApp.allAccounts() {
                try msalApp.remove(account)
            }
        } catch {
            errorMessage = "Sign out error: \(error.localizedDescription)"
        }

        userUPN = nil
        isEnrolled = false
        enrollmentStatus = "Signed out"
    }

    // MARK: - Enrollment Notifications

    private func observeEnrollmentNotifications() {
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .intuneEnrollmentSucceeded) {
                guard let self else { return }
                self.isEnrolled = true
                self.enrollmentStatus = "✅ Enrolled — policies active"
                self.refreshMAMAppConfig()
            }
        }
        Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(named: .intuneEnrollmentFailed) {
                guard let self else { return }
                self.isEnrolled = false
                self.enrollmentStatus = "❌ Enrollment failed"
                self.errorMessage = notification.object as? String
            }
        }
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .intuneUnenrolled) {
                guard let self else { return }
                self.isEnrolled = false
                self.userUPN = nil
                self.enrollmentStatus = "Unenrolled"
            }
        }
    }

    // MARK: - Helpers

    private func presentingViewController() throws -> UIViewController {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              let rootVC = scene.windows.first(where: \.isKeyWindow)?.rootViewController
        else {
            throw AuthError.noPresentingViewController
        }
        return rootVC
    }

    var managedConfig: [(key: String, value: String)] {
        let raw = UserDefaults.standard.dictionary(forKey: "com.apple.configuration.managed") ?? [:]
        return raw.keys.sorted().map { key in
            (key, String(describing: raw[key] ?? "nil"))
        }
    }

}

extension Bundle {
    func intuneMAMSetting(for key: String) -> String? {
        let settings = infoDictionary?["IntuneMAMSettings"] as? [String: Any]
        return settings?[key] as? String
    }
}
