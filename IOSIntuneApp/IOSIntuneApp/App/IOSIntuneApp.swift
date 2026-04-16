//
//  IOSIntuneAppApp.swift
//  IOSIntuneApp
//
//  Created by Anthony Pham on 4/16/26.
//

import SwiftUI
import IntuneMAMSwift

@main
struct IOSIntuneApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
