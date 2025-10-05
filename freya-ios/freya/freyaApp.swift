//
//  freyaApp.swift
//  freya
//
//  Created by Prithvi B on 9/26/25.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    return true
  }
}

@main
struct freyaApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var userSession = UserSession()
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                StartView() // Always start with splash screen
            }
            .environmentObject(userSession)
        }
    }
}
