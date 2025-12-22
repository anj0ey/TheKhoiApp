//
//  AppDelegate.swift
//  TheKhoiApp
//
//  Handles Firebase configuration and push notifications via FCM
//

import SwiftUI
import FirebaseCore
import FirebaseMessaging
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
        
        // Set FCM messaging delegate
        Messaging.messaging().delegate = NotificationService.shared
        
        // Check notification authorization status
        NotificationService.shared.checkAuthorizationStatus()
        
        // Register for remote notifications if authorized
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .authorized {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
        
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
    
    // MARK: - Remote Notification Registration
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Pass device token to Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        
        // Log for debugging
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("APNs Device Token: \(token)")
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // MARK: - Handle Remote Notifications (Background/Terminated)
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("Received remote notification: \(userInfo)")
        
        // Let FCM handle the message
        if let messageId = userInfo["gcm.message_id"] {
            print("Message ID: \(messageId)")
        }
        
        // Handle data payload if needed
        if let aps = userInfo["aps"] as? [String: Any] {
            print("APS payload: \(aps)")
        }
        
        completionHandler(.newData)
    }
}
