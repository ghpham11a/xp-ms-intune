//
//  IntuneHelloWorldApp.swift
//  IntuneHelloWorld
//
//  Created by Anthony Pham on 4/14/26.
//

import SwiftUI
import IntuneMAMSwift

@main
struct IntuneHelloWorldApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
