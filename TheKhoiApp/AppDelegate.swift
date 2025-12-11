//
//  AppDelegate.swift
//  TheKhoiApp
//
//  Created by iya student on 12/1/25.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Setup notification categories
        NotificationService.shared.setupNotificationCategories()
        
        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = NotificationService.shared
        
        // Check notification authorization status
        NotificationService.shared.checkAuthorizationStatus()
        
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        // Let Google Sign-In handle the callback URL
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    // MARK: - Remote Notification Registration (for future push notifications)
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Convert token to string for debugging
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("Device Token: \(token)")
        
        // TODO: Send this token to your server for push notifications
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
}
