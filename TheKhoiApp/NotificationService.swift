//
//  NotificationService.swift
//  TheKhoiApp
//
//  Service for managing local notifications for appointments and pro applications
//

import Foundation
import UserNotifications
import FirebaseFirestore

class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let db = Firestore.firestore()
    
    // Notification identifiers
    private let appointmentReminderPrefix = "appointment_reminder_"
    private let appointmentDayBeforePrefix = "appointment_day_before_"
    private let proApplicationPrefix = "pro_application_"
    
    override init() {
        super.init()
        notificationCenter.delegate = self
        checkAuthorizationStatus()
    }
    
    // MARK: - Permission Handling
    
    /// Check current authorization status
    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    /// Request notification permission from user
    func requestPermission(completion: @escaping (Bool) -> Void) {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                self?.authorizationStatus = granted ? .authorized : .denied
                
                if let error = error {
                    print("❌ Notification permission error: \(error.localizedDescription)")
                }
                
                completion(granted)
            }
        }
    }
    
    /// Check if we should ask for permission (not yet determined)
    func shouldRequestPermission() -> Bool {
        return authorizationStatus == .notDetermined
    }
    
    // MARK: - Appointment Notifications
    
    /// Schedule notifications for an appointment (1 hour before and 1 day before)
    func scheduleAppointmentReminders(for appointment: Appointment) {
        guard isAuthorized else {
            print("⚠️ Notifications not authorized")
            return
        }
        
        // Cancel any existing reminders for this appointment
        cancelAppointmentReminders(appointmentId: appointment.id)
        
        // Parse the appointment time
        guard let appointmentDateTime = combineDateAndTime(date: appointment.date, timeString: appointment.timeSlot) else {
            print("❌ Could not parse appointment time")
            return
        }
        
        // 1. Schedule 1 hour before reminder
        let oneHourBefore = appointmentDateTime.addingTimeInterval(-3600) // 1 hour = 3600 seconds
        if oneHourBefore > Date() {
            scheduleNotification(
                identifier: "\(appointmentReminderPrefix)\(appointment.id)",
                title: "Appointment in 1 Hour",
                body: "Your \(appointment.serviceName) appointment with \(appointment.artistName) is coming up at \(appointment.timeSlot).",
                date: oneHourBefore,
                categoryIdentifier: "APPOINTMENT_REMINDER"
            )
        }
        
        // 2. Schedule 1 day before reminder (at 9 AM)
        let calendar = Calendar.current
        if let dayBefore = calendar.date(byAdding: .day, value: -1, to: appointment.date) {
            var components = calendar.dateComponents([.year, .month, .day], from: dayBefore)
            components.hour = 9
            components.minute = 0
            
            if let reminderDate = calendar.date(from: components), reminderDate > Date() {
                scheduleNotification(
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
    
    /// Cancel appointment reminders
    func cancelAppointmentReminders(appointmentId: String) {
        let identifiers = [
            "\(appointmentReminderPrefix)\(appointmentId)",
            "\(appointmentDayBeforePrefix)\(appointmentId)"
        ]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        print("🗑️ Cancelled reminders for appointment \(appointmentId)")
    }
    
    // MARK: - Pro Application Notifications
    
    /// Send notification when pro application status changes
    func sendProApplicationStatusNotification(status: String, businessName: String) {
        guard isAuthorized else { return }
        
        let title: String
        let body: String
        
        switch status.lowercased() {
        case "approved":
            title = "Congratulations! 🎉"
            body = "Your pro application for \(businessName) has been approved! You can now switch to Pro mode and start accepting bookings."
        case "rejected":
            title = "Application Update"
            body = "Your pro application for \(businessName) was not approved at this time. Please review the feedback and try again."
        case "pending":
            title = "Application Received"
            body = "Your pro application for \(businessName) has been submitted. We'll review it within 24-48 hours."
        default:
            return
        }
        
        // Send immediately
        scheduleNotification(
            identifier: "\(proApplicationPrefix)\(UUID().uuidString)",
            title: title,
            body: body,
            date: Date().addingTimeInterval(1), // 1 second from now
            categoryIdentifier: "PRO_APPLICATION"
        )
    }
    
    // MARK: - Booking Confirmation Notifications
    
    /// Notify client when their booking is confirmed
    func sendBookingConfirmedNotification(appointment: Appointment) {
        guard isAuthorized else { return }
        
        scheduleNotification(
            identifier: "booking_confirmed_\(appointment.id)",
            title: "Booking Confirmed! ✓",
            body: "Your \(appointment.serviceName) appointment with \(appointment.artistName) on \(appointment.formattedDate) at \(appointment.timeSlot) has been confirmed.",
            date: Date().addingTimeInterval(1),
            categoryIdentifier: "BOOKING_UPDATE"
        )
        
        // Also schedule the reminders now that it's confirmed
        scheduleAppointmentReminders(for: appointment)
    }
    
    /// Notify client when their booking is cancelled
    func sendBookingCancelledNotification(appointment: Appointment, reason: String?) {
        guard isAuthorized else { return }
        
        var body = "Your \(appointment.serviceName) appointment with \(appointment.artistName) on \(appointment.formattedDate) has been cancelled."
        if let reason = reason, !reason.isEmpty {
            body += " Reason: \(reason)"
        }
        
        scheduleNotification(
            identifier: "booking_cancelled_\(appointment.id)",
            title: "Booking Cancelled",
            body: body,
            date: Date().addingTimeInterval(1),
            categoryIdentifier: "BOOKING_UPDATE"
        )
        
        // Cancel any scheduled reminders
        cancelAppointmentReminders(appointmentId: appointment.id)
    }
    
    /// Notify pro when they receive a new booking request
    func sendNewBookingRequestNotification(appointment: Appointment) {
        guard isAuthorized else { return }
        
        scheduleNotification(
            identifier: "new_booking_\(appointment.id)",
            title: "New Booking Request",
            body: "\(appointment.clientName) wants to book \(appointment.serviceName) on \(appointment.formattedDate) at \(appointment.timeSlot).",
            date: Date().addingTimeInterval(1),
            categoryIdentifier: "NEW_BOOKING"
        )
    }
    
    // MARK: - Helper Methods
    
    private func scheduleNotification(
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
        
        // Create trigger based on date
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("✅ Scheduled notification: \(identifier) for \(date)")
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
        // Appointment reminder actions
        let viewAction = UNNotificationAction(
            identifier: "VIEW_APPOINTMENT",
            title: "View Details",
            options: .foreground
        )
        
        let appointmentCategory = UNNotificationCategory(
            identifier: "APPOINTMENT_REMINDER",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Booking update actions
        let bookingCategory = UNNotificationCategory(
            identifier: "BOOKING_UPDATE",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        // New booking actions (for pros)
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
        
        // Pro application category
        let proApplicationCategory = UNNotificationCategory(
            identifier: "PRO_APPLICATION",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([
            appointmentCategory,
            bookingCategory,
            newBookingCategory,
            proApplicationCategory
        ])
    }
    
    // MARK: - Listen for Pro Application Status Changes
    
    func listenForProApplicationStatus(userId: String) {
        db.collection("pro_applications").document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let data = snapshot?.data(),
                      let status = data["status"] as? String,
                      let businessName = data["businessName"] as? String else { return }
                
                // Check if status changed (compare with stored value)
                let lastStatus = UserDefaults.standard.string(forKey: "lastProApplicationStatus_\(userId)")
                
                if lastStatus != status && lastStatus != nil {
                    // Status changed, send notification
                    self?.sendProApplicationStatusNotification(status: status, businessName: businessName)
                }
                
                // Store current status
                UserDefaults.standard.set(status, forKey: "lastProApplicationStatus_\(userId)")
            }
    }
    
    // MARK: - Clear All Notifications
    
    func clearAllPendingNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
    func clearAllDeliveredNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        let actionIdentifier = response.actionIdentifier
        
        print("📱 Notification tapped: \(identifier), action: \(actionIdentifier)")
        
        // Handle different actions
        switch actionIdentifier {
        case "VIEW_APPOINTMENT", UNNotificationDefaultActionIdentifier:
            // Navigate to appointments view
            NotificationCenter.default.post(name: .openAppointments, object: nil)
        case "CONFIRM_BOOKING":
            // Handle booking confirmation
            NotificationCenter.default.post(name: .openAppointments, object: nil)
        default:
            break
        }
        
        completionHandler()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let openAppointments = Notification.Name("openAppointments")
    static let openProApplication = Notification.Name("openProApplication")
}
