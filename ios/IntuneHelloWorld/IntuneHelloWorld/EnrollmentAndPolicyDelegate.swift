//
//  PolicyDelegate.swift
//  IntuneHelloWorld
//
//  Created by Anthony Pham on 4/14/26.
//

import Foundation
import IntuneMAMSwift

class EnrollmentAndPolicyDelegate: NSObject, IntuneMAMPolicyDelegate, IntuneMAMEnrollmentDelegate {

    // MARK: - IntuneMAMPolicyDelegate
    
    /// Called when IT issues a selective wipe for a specific user.
    /// Delete all data belonging to that UPN and return true.
    func wipeData(forAccountId upn: String) -> Bool {
        print("Intune: wiping data for \(upn)")
        // TODO: clear keychain entries, Core Data, files for this user
        return true
    }

    /// Called when the SDK needs to restart the app to apply policy.
    func restartApplication() -> Bool {
        // Return false to let the SDK show its own "please restart" dialog,
        // or return true if you handle the restart yourself.
        return false
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
