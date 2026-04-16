//
//  AppDelegate.swift
//  IOSIntuneApp
//
//  Created by Anthony Pham on 4/16/26.
//

import UIKit
import IntuneMAMSwift
import MSAL

class AppDelegate: NSObject, UIApplicationDelegate {
    
    let enrollmentAndPolicyDelegate = EnrollmentAndPolicyDelegate()
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        
        IntuneMAMEnrollmentManager.instance().delegate = enrollmentAndPolicyDelegate
        IntuneMAMPolicyManager.instance().delegate = enrollmentAndPolicyDelegate

        print("✅ Intune MAM SDK initialized")
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        let sourceApp = options[.sourceApplication] as? String
        return MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: sourceApp)
    }
}

// MARK: - Notification names
extension Notification.Name {
    static let intuneEnrollmentSucceeded = Notification.Name("intuneEnrollmentSucceeded")
    static let intuneEnrollmentFailed    = Notification.Name("intuneEnrollmentFailed")
    static let intuneUnenrolled          = Notification.Name("intuneUnenrolled")
}

