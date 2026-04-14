//
//  AppDelegate.swift
//  IntuneHelloWorld
//
//  Created by Anthony Pham on 4/14/26.
//

import UIKit
import IntuneMAMSwift
import MSAL

class AppDelegate: NSObject, UIApplicationDelegate, IntuneMAMEnrollmentDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        
        // Set yourself as the enrollment delegate
        // This gives you callbacks when enrollment succeeds/fails
        IntuneMAMEnrollmentManager.instance().delegate = self
        
        print("✅ Intune MAM SDK initialized")
        return true
    }
    
    // MARK: - IntuneMAMEnrollmentDelegate
    
    // Called when MAM enrollment completes
    func enrollmentRequest(with status: IntuneMAMEnrollmentStatus) {
        logStatus("enrollmentRequest", status: status)
        if status.didSucceed {
            NotificationCenter.default.post(name: .intuneEnrollmentSucceeded, object: status.identity)
        } else {
            NotificationCenter.default.post(name: .intuneEnrollmentFailed, object: status.errorString)
        }
    }

    // Called when a policy-check operation finishes (including "no policy assigned")
    func policyRequest(with status: IntuneMAMEnrollmentStatus) {
        logStatus("policyRequest", status: status)
        if status.didSucceed {
            NotificationCenter.default.post(name: .intuneEnrollmentSucceeded, object: status.identity)
        } else {
            NotificationCenter.default.post(name: .intuneEnrollmentFailed, object: status.errorString)
        }
    }

    // Called when a policy/unenrollment wipe is triggered by IT
    func unenrollRequest(with status: IntuneMAMEnrollmentStatus) {
        logStatus("unenrollRequest", status: status)
        if status.didSucceed {
            NotificationCenter.default.post(name: .intuneUnenrolled, object: nil)
        }
    }

    private func logStatus(_ label: String, status: IntuneMAMEnrollmentStatus) {
        print("📣 \(label) — didSucceed=\(status.didSucceed) statusCode=\(status.statusCode.rawValue) identity=\(status.identity) error=\(status.errorString ?? "nil")")
    }
}

// MARK: - Notification names
extension Notification.Name {
    static let intuneEnrollmentSucceeded = Notification.Name("intuneEnrollmentSucceeded")
    static let intuneEnrollmentFailed    = Notification.Name("intuneEnrollmentFailed")
    static let intuneUnenrolled          = Notification.Name("intuneUnenrolled")
}
