//
//  AppDelegate.swift
//  IntuneHelloWorld
//
//  Created by Anthony Pham on 4/14/26.
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
        
        // Set yourself as the enrollment delegate
        // This gives you callbacks when enrollment succeeds/fails
        // IntuneMAMEnrollmentManager.instance().delegate = self
        // Register policy delegate (selective wipe, restart, etc.)
        IntuneMAMPolicyManager.instance().delegate = enrollmentAndPolicyDelegate
        
        print("✅ Intune MAM SDK initialized")
        return true
    }
}

// MARK: - Notification names
extension Notification.Name {
    static let intuneEnrollmentSucceeded = Notification.Name("intuneEnrollmentSucceeded")
    static let intuneEnrollmentFailed    = Notification.Name("intuneEnrollmentFailed")
    static let intuneUnenrolled          = Notification.Name("intuneUnenrolled")
}
