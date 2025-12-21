//
//  NotificationService.swift
//  TheKhoiApp
//
//  Service for managing push notifications via FCM and local notifications
//

import Foundation
import UserNotifications
import FirebaseFirestore
import FirebaseMessaging
import UIKit

class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var fcmToken: String?
    @Published var unreadNotificationCount: Int = 0
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let db = Firestore.firestore()
    private var notificationsListener: ListenerRegistration?
    
    // Notification identifiers
    private let appointmentReminderPrefix = "appointment_reminder_"
    private let appointmentDayBeforePrefix = "appointment_day_before_"
    private let proApplicationPrefix = "pro_application_"
    
    override init() {
        super.init()
        notificationCenter.delegate = self
        Messaging.messaging().delegate = self
        checkAuthorizationStatus()
    }
    
    // MARK: - Permission Handling
    
    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                self?.authorizationStatus = granted ? .authorized : .denied
                
                if granted {
                    // Register for remote notifications
                    UIApplication.shared.registerForRemoteNotifications()
                }
                
                if let error = error {
                    print("❌ Notification permission error: \(error.localizedDescription)")
                }
                
                completion(granted)
            }
        }
    }
    
    func shouldRequestPermission() -> Bool {
        return authorizationStatus == .notDetermined
    }
    
    // MARK: - FCM Token Management
    
    /// Save FCM token to Firestore for the user
    func saveFCMToken(userId: String) {
        guard let token = fcmToken else {
            print("⚠️ No FCM token available")
            return
        }
        
        db.collection("users").document(userId).updateData([
            "fcmToken": token,
            "fcmTokenUpdatedAt": Timestamp(date: Date()),
            "deviceType": "iOS"
        ]) { error in
            if let error = error {
                print("❌ Error saving FCM token: \(error.localizedDescription)")
            } else {
                print("✅ FCM token saved for user: \(userId)")
            }
        }
    }
    
    /// Remove FCM token when user logs out
    func removeFCMToken(userId: String) {
        db.collection("users").document(userId).updateData([
            "fcmToken": FieldValue.delete(),
            "fcmTokenUpdatedAt": FieldValue.delete()
        ]) { error in
            if let error = error {
                print("❌ Error removing FCM token: \(error.localizedDescription)")
            } else {
                print("✅ FCM token removed for user: \(userId)")
            }
        }
    }
    
    // MARK: - Create Notification in Firestore
    // These notifications are stored in Firestore and trigger FCM via Cloud Functions
    
    /// Create a notification document in Firestore
    private func createNotification(
        recipientId: String,
        type: NotificationType,
        title: String,
        body: String,
        data: [String: Any] = [:]
    ) {
        let notificationData: [String: Any] = [
            "recipientId": recipientId,
            "type": type.rawValue,
            "title": title,
            "body": body,
            "data": data,
            "isRead": false,
            "createdAt": Timestamp(date: Date())
        ]
        
        db.collection("notifications").addDocument(data: notificationData) { error in
            if let error = error {
                print("❌ Error creating notification: \(error.localizedDescription)")
            } else {
                print("✅ Notification created for \(recipientId): \(type.rawValue)")
            }
        }
    }
    
    // MARK: - Chat Notifications
    
    /// Send notification for new chat message
    func sendNewMessageNotification(
        recipientId: String,
        senderName: String,
        messagePreview: String,
        conversationId: String
    ) {
        createNotification(
            recipientId: recipientId,
            type: .newMessage,
            title: "New message from \(senderName)",
            body: messagePreview.prefix(100).description,
            data: [
                "conversationId": conversationId,
                "senderName": senderName
            ]
        )
    }
    
    // MARK: - Comment Notifications
    
    /// Send notification when someone comments on user's post
    func sendNewCommentNotification(
        postOwnerId: String,
        commenterName: String,
        commentPreview: String,
        postId: String
    ) {
        createNotification(
            recipientId: postOwnerId,
            type: .newComment,
            title: "\(commenterName) commented on your post",
            body: commentPreview.prefix(100).description,
            data: [
                "postId": postId,
                "commenterName": commenterName
            ]
        )
    }
    
    // MARK: - Booking Notifications
    
    /// Notify client when their booking is confirmed
    func sendBookingConfirmedNotification(appointment: Appointment) {
        createNotification(
            recipientId: appointment.clientId,
            type: .bookingConfirmed,
            title: "Booking Confirmed! ✓",
            body: "Your \(appointment.serviceName) appointment with \(appointment.artistName) on \(appointment.formattedDate) at \(appointment.timeSlot) has been confirmed.",
            data: [
                "appointmentId": appointment.id,
                "artistId": appointment.artistId
            ]
        )
        
        // Also schedule local reminders
        scheduleAppointmentReminders(for: appointment)
    }
    
    /// Notify client when their booking is cancelled
    func sendBookingCancelledNotification(appointment: Appointment, reason: String?) {
        var body = "Your \(appointment.serviceName) appointment with \(appointment.artistName) on \(appointment.formattedDate) has been cancelled."
        if let reason = reason, !reason.isEmpty {
            body += " Reason: \(reason)"
        }
        
        createNotification(
            recipientId: appointment.clientId,
            type: .bookingCancelled,
            title: "Booking Cancelled",
            body: body,
            data: [
                "appointmentId": appointment.id,
                "reason": reason ?? ""
            ]
        )
        
        // Cancel local reminders
        cancelAppointmentReminders(appointmentId: appointment.id)
    }
    
    /// Notify pro when they receive a new booking request
    func sendNewBookingRequestNotification(appointment: Appointment) {
        createNotification(
            recipientId: appointment.artistId,
            type: .newBookingRequest,
            title: "New Booking Request",
            body: "\(appointment.clientName) wants to book \(appointment.serviceName) on \(appointment.formattedDate) at \(appointment.timeSlot).",
            data: [
                "appointmentId": appointment.id,
                "clientId": appointment.clientId,
                "clientName": appointment.clientName
            ]
        )
    }
    
    /// Send appointment reminder (1 hour before)
    func sendAppointmentReminderNotification(appointment: Appointment, isForArtist: Bool) {
        let recipientId = isForArtist ? appointment.artistId : appointment.clientId
        let withName = isForArtist ? appointment.clientName : appointment.artistName
        
        createNotification(
            recipientId: recipientId,
            type: .appointmentReminder,
            title: "Appointment in 1 Hour",
            body: "Your \(appointment.serviceName) appointment with \(withName) is coming up at \(appointment.timeSlot).",
            data: [
                "appointmentId": appointment.id
            ]
        )
    }
    
    // MARK: - Pro Application Notifications
    
    func sendProApplicationStatusNotification(status: String, businessName: String, userId: String) {
        let title: String
        let body: String
        let type: NotificationType
        
        switch status.lowercased() {
        case "approved":
            title = "Congratulations! 🎉"
            body = "Your pro application for \(businessName) has been approved! You can now switch to Pro mode and start accepting bookings."
            type = .proApplicationApproved
        case "rejected":
            title = "Application Update"
            body = "Your pro application for \(businessName) was not approved at this time. Please review the feedback and try again."
            type = .proApplicationRejected
        default:
            return
        }
        
        createNotification(
            recipientId: userId,
            type: type,
            title: title,
            body: body,
            data: ["businessName": businessName]
        )
    }
    
    // MARK: - Post Interaction Notifications
    
    /// Send notification when someone saves user's post
    func sendPostSavedNotification(
        postOwnerId: String,
        saverName: String,
        postId: String
    ) {
        createNotification(
            recipientId: postOwnerId,
            type: .postSaved,
            title: "\(saverName) saved your post",
            body: "Your post is getting noticed! Keep creating great content.",
            data: [
                "postId": postId,
                "saverName": saverName
            ]
        )
    }
    
    // MARK: - Follow Notifications
    
    /// Send notification when someone follows user
    func sendNewFollowerNotification(
        userId: String,
        followerName: String,
        followerUsername: String,
        followerId: String
    ) {
        createNotification(
            recipientId: userId,
            type: .newFollower,
            title: "New Follower",
            body: "\(followerName) (@\(followerUsername)) started following you.",
            data: [
                "followerId": followerId,
                "followerName": followerName
            ]
        )
    }
    
    // MARK: - Listen to User's Notifications
    
    func listenToNotifications(userId: String) {
        notificationsListener?.remove()
        
        notificationsListener = db.collection("notifications")
            .whereField("recipientId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self?.unreadNotificationCount = documents.count
                    UIApplication.shared.applicationIconBadgeNumber = documents.count
                }
            }
    }
    
    /// Mark notification as read
    func markNotificationAsRead(notificationId: String) {
        db.collection("notifications").document(notificationId).updateData([
            "isRead": true,
            "readAt": Timestamp(date: Date())
        ])
    }
    
    /// Mark all notifications as read
    func markAllNotificationsAsRead(userId: String) {
        db.collection("notifications")
            .whereField("recipientId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                let batch = self?.db.batch()
                for doc in documents {
                    batch?.updateData([
                        "isRead": true,
                        "readAt": Timestamp(date: Date())
                    ], forDocument: doc.reference)
                }
                
                batch?.commit { error in
                    if let error = error {
                        print("❌ Error marking notifications as read: \(error)")
                    } else {
                        DispatchQueue.main.async {
                            self?.unreadNotificationCount = 0
                            UIApplication.shared.applicationIconBadgeNumber = 0
                        }
                    }
                }
            }
    }
    
    // MARK: - Local Appointment Reminders
    
    func scheduleAppointmentReminders(for appointment: Appointment) {
        guard isAuthorized else {
            print("⚠️ Notifications not authorized")
            return
        }
        
        cancelAppointmentReminders(appointmentId: appointment.id)
        
        guard let appointmentDateTime = combineDateAndTime(date: appointment.date, timeString: appointment.timeSlot) else {
            print("❌ Could not parse appointment time")
            return
        }
        
        // 1 hour before
        let oneHourBefore = appointmentDateTime.addingTimeInterval(-3600)
        if oneHourBefore > Date() {
            scheduleLocalNotification(
                identifier: "\(appointmentReminderPrefix)\(appointment.id)",
                title: "Appointment in 1 Hour",
                body: "Your \(appointment.serviceName) appointment with \(appointment.artistName) is coming up at \(appointment.timeSlot).",
                date: oneHourBefore,
                categoryIdentifier: "APPOINTMENT_REMINDER"
            )
        }
        
        // 1 day before at 9 AM
        let calendar = Calendar.current
        if let dayBefore = calendar.date(byAdding: .day, value: -1, to: appointment.date) {
            var components = calendar.dateComponents([.year, .month, .day], from: dayBefore)
            components.hour = 9
            components.minute = 0
            
            if let reminderDate = calendar.date(from: components), reminderDate > Date() {
                scheduleLocalNotification(
                    identifier: "\(appointmentDayBeforePrefix)\(appointment.id)",
                    title: "Appointment Tomorrow",
                    body: "Reminder: You have a \(appointment.serviceName) appointment with \(appointment.artistName) tomorrow at \(appointment.timeSlot).",
                    date: reminderDate,
                    categoryIdentifier: "APPOINTMENT_REMINDER"
                )
            }
        }
        
        print("✅ Scheduled appointment reminders for \(appointment.id)")
    }
    
    func cancelAppointmentReminders(appointmentId: String) {
        let identifiers = [
            "\(appointmentReminderPrefix)\(appointmentId)",
            "\(appointmentDayBeforePrefix)\(appointmentId)"
        ]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        print("🗑️ Cancelled reminders for appointment \(appointmentId)")
    }
    
    // MARK: - Helper Methods
    
    private func scheduleLocalNotification(
        identifier: String,
        title: String,
        body: String,
        date: Date,
        categoryIdentifier: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("✅ Scheduled local notification: \(identifier) for \(date)")
            }
        }
    }
    
    private func combineDateAndTime(date: Date, timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        guard let time = formatter.date(from: timeString) else { return nil }
        
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        
        return calendar.date(from: combined)
    }
    
    // MARK: - Notification Categories Setup
    
    func setupNotificationCategories() {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ACTION",
            title: "View",
            options: .foreground
        )
        
        let replyAction = UNTextInputNotificationAction(
            identifier: "REPLY_MESSAGE",
            title: "Reply",
            options: .foreground,
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Type a message..."
        )
        
        // Chat message category
        let chatCategory = UNNotificationCategory(
            identifier: "CHAT_MESSAGE",
            actions: [viewAction, replyAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Comment category
        let commentCategory = UNNotificationCategory(
            identifier: "NEW_COMMENT",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Appointment reminder
        let appointmentCategory = UNNotificationCategory(
            identifier: "APPOINTMENT_REMINDER",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Booking update
        let bookingCategory = UNNotificationCategory(
            identifier: "BOOKING_UPDATE",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        // New booking (for pros)
        let confirmAction = UNNotificationAction(
            identifier: "CONFIRM_BOOKING",
            title: "Confirm",
            options: .foreground
        )
        
        let newBookingCategory = UNNotificationCategory(
            identifier: "NEW_BOOKING",
            actions: [viewAction, confirmAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Pro application
        let proCategory = UNNotificationCategory(
            identifier: "PRO_APPLICATION",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Social (follows, saves)
        let socialCategory = UNNotificationCategory(
            identifier: "SOCIAL",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([
            chatCategory,
            commentCategory,
            appointmentCategory,
            bookingCategory,
            newBookingCategory,
            proCategory,
            socialCategory
        ])
    }
    
    // MARK: - Listen for Pro Application Status Changes
    
    func listenForProApplicationStatus(userId: String) {
        db.collection("pro_applications").document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let data = snapshot?.data(),
                      let status = data["status"] as? String,
                      let businessName = data["businessName"] as? String else { return }
                
                let lastStatus = UserDefaults.standard.string(forKey: "lastProApplicationStatus_\(userId)")
                
                if lastStatus != status && lastStatus != nil {
                    self?.sendProApplicationStatusNotification(status: status, businessName: businessName, userId: userId)
                }
                
                UserDefaults.standard.set(status, forKey: "lastProApplicationStatus_\(userId)")
            }
    }
    
    // MARK: - Cleanup
    
    func stopListening() {
        notificationsListener?.remove()
    }
    
    func clearAllPendingNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
    func clearAllDeliveredNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
    }
}

// MARK: - Notification Types
enum NotificationType: String {
    case newMessage = "new_message"
    case newComment = "new_comment"
    case newBookingRequest = "new_booking_request"
    case bookingConfirmed = "booking_confirmed"
    case bookingCancelled = "booking_cancelled"
    case appointmentReminder = "appointment_reminder"
    case proApplicationApproved = "pro_application_approved"
    case proApplicationRejected = "pro_application_rejected"
    case postSaved = "post_saved"
    case newFollower = "new_follower"
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let identifier = response.notification.request.identifier
        let actionIdentifier = response.actionIdentifier
        
        print("📱 Notification tapped: \(identifier), action: \(actionIdentifier)")
        print("📦 UserInfo: \(userInfo)")
        
        // Extract notification type and data
        if let type = userInfo["type"] as? String {
            switch type {
            case "new_message":
                if let conversationId = userInfo["conversationId"] as? String {
                    NotificationCenter.default.post(
                        name: .openChat,
                        object: nil,
                        userInfo: ["conversationId": conversationId]
                    )
                }
            case "new_comment":
                if let postId = userInfo["postId"] as? String {
                    NotificationCenter.default.post(
                        name: .openPost,
                        object: nil,
                        userInfo: ["postId": postId]
                    )
                }
            case "new_booking_request", "booking_confirmed", "booking_cancelled", "appointment_reminder":
                NotificationCenter.default.post(name: .openAppointments, object: nil)
            case "pro_application_approved", "pro_application_rejected":
                NotificationCenter.default.post(name: .openProApplication, object: nil)
            case "new_follower":
                if let followerId = userInfo["followerId"] as? String {
                    NotificationCenter.default.post(
                        name: .openProfile,
                        object: nil,
                        userInfo: ["userId": followerId]
                    )
                }
            default:
                break
            }
        } else {
            // Handle local notifications (appointment reminders)
            if identifier.hasPrefix(appointmentReminderPrefix) || identifier.hasPrefix(appointmentDayBeforePrefix) {
                NotificationCenter.default.post(name: .openAppointments, object: nil)
            }
        }
        
        // Handle quick reply for messages
        if actionIdentifier == "REPLY_MESSAGE",
           let textResponse = response as? UNTextInputNotificationResponse {
            let replyText = textResponse.userText
            if let conversationId = userInfo["conversationId"] as? String {
                NotificationCenter.default.post(
                    name: .replyToMessage,
                    object: nil,
                    userInfo: [
                        "conversationId": conversationId,
                        "replyText": replyText
                    ]
                )
            }
        }
        
        completionHandler()
    }
}

// MARK: - MessagingDelegate
extension NotificationService: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("📲 FCM Token: \(fcmToken ?? "nil")")
        
        DispatchQueue.main.async {
            self.fcmToken = fcmToken
        }
        
        // Post notification so AuthManager can save the token
        NotificationCenter.default.post(
            name: .fcmTokenReceived,
            object: nil,
            userInfo: ["token": fcmToken ?? ""]
        )
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let openAppointments = Notification.Name("openAppointments")
    static let openProApplication = Notification.Name("openProApplication")
    static let openChat = Notification.Name("openChat")
    static let openPost = Notification.Name("openPost")
    static let openProfile = Notification.Name("openProfile")
    static let replyToMessage = Notification.Name("replyToMessage")
    static let fcmTokenReceived = Notification.Name("fcmTokenReceived")
}
