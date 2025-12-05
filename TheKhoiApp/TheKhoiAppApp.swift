//
//  TheKhoiAppApp.swift
//  TheKhoiApp
//
//  Created by Anjo on 11/6/25.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct TheKhoiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            ContentView(authManager: authManager)
                .environmentObject(authManager)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

