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
    @StateObject private var notificationService = NotificationService.shared
    
    // Track if we should show notification permission prompt
    @State private var showNotificationPrompt = false

    var body: some Scene {
        WindowGroup {
            ContentView(authManager: authManager)
                .environmentObject(authManager)
                .environmentObject(notificationService)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: .openAppointments)) { _ in
                    // Handle navigation to appointments
                    // This would need to update a @State variable to switch tabs
                }
                .onChange(of: authManager.isOnboardingComplete) { completed in
                    // Show notification permission after user completes onboarding
                    if completed {
                        checkAndShowNotificationPrompt()
                    }
                }
                .sheet(isPresented: $showNotificationPrompt) {
                    NotificationPermissionView(isPresented: $showNotificationPrompt) { granted in
                        if granted {
                            print("✅ User granted notification permission")
                            // Start listening for pro application status if user has pending application
                            if let userId = authManager.firebaseUID, authManager.hasPendingProApplication {
                                notificationService.listenForProApplicationStatus(userId: userId)
                            }
                        }
                    }
                }
        }
    }
    
    private func checkAndShowNotificationPrompt() {
        // Only show if permission not yet determined
        guard notificationService.shouldRequestPermission() else { return }
        
        // Check if user previously skipped
        let skipped = UserDefaults.standard.bool(forKey: "notificationPermissionSkipped")
        if skipped {
            // Check if it's been more than 7 days since they skipped
            if let skippedDate = UserDefaults.standard.object(forKey: "notificationPermissionSkippedDate") as? Date {
                let daysSinceSkip = Calendar.current.dateComponents([.day], from: skippedDate, to: Date()).day ?? 0
                if daysSinceSkip < 7 {
                    return // Don't show again yet
                }
            }
        }
        
        // Show the prompt after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showNotificationPrompt = true
        }
    }
}
