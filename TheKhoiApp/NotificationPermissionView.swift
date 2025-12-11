//
//  NotificationPermissionView.swift
//  TheKhoiApp
//
//  View for requesting notification permissions
//

import SwiftUI

struct NotificationPermissionView: View {
    @ObservedObject var notificationService = NotificationService.shared
    @Binding var isPresented: Bool
    var onComplete: ((Bool) -> Void)?
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(KHOIColors.accentBrown.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 44))
                    .foregroundColor(KHOIColors.accentBrown)
            }
            
            // Title and description
            VStack(spacing: 12) {
                Text("Stay in the Loop")
                    .font(KHOITheme.title)
                    .foregroundColor(KHOIColors.darkText)
                
                Text("Enable notifications to get reminders about your upcoming appointments and important updates.")
                    .font(KHOITheme.body)
                    .foregroundColor(KHOIColors.mutedText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            // Benefits list
            VStack(alignment: .leading, spacing: 16) {
                NotificationBenefitRow(
                    icon: "calendar.badge.clock",
                    title: "Appointment Reminders",
                    description: "Get notified before your appointments"
                )
                
                NotificationBenefitRow(
                    icon: "checkmark.circle",
                    title: "Booking Updates",
                    description: "Know when your booking is confirmed"
                )
                
                NotificationBenefitRow(
                    icon: "star.fill",
                    title: "Pro Status Updates",
                    description: "Track your pro application status"
                )
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            
            Spacer()
            
            // Buttons
            VStack(spacing: 12) {
                Button(action: enableNotifications) {
                    Text("Enable Notifications")
                        .font(KHOITheme.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(KHOIColors.accentBrown)
                        .cornerRadius(12)
                }
                
                Button(action: skipNotifications) {
                    Text("Maybe Later")
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.mutedText)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(KHOIColors.background.ignoresSafeArea())
    }
    
    private func enableNotifications() {
        notificationService.requestPermission { granted in
            onComplete?(granted)
            isPresented = false
        }
    }
    
    private func skipNotifications() {
        // Mark as skipped so we don't ask again immediately
        UserDefaults.standard.set(true, forKey: "notificationPermissionSkipped")
        UserDefaults.standard.set(Date(), forKey: "notificationPermissionSkippedDate")
        onComplete?(false)
        isPresented = false
    }
}

// MARK: - Benefit Row
struct NotificationBenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(KHOIColors.accentBrown)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(KHOITheme.bodyBold)
                    .foregroundColor(KHOIColors.darkText)
                
                Text(description)
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.mutedText)
            }
        }
    }
}

// MARK: - Notification Settings Row (for Settings screen)
struct NotificationSettingsRow: View {
    @ObservedObject var notificationService = NotificationService.shared
    @State private var showPermissionSheet = false
    
    var body: some View {
        Button(action: handleTap) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(KHOIColors.accentBrown)
                    .frame(width: 24)
                
                Text("Notifications")
                    .font(KHOITheme.body)
                    .foregroundColor(KHOIColors.darkText)
                
                Spacer()
                
                Text(statusText)
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.mutedText)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(KHOIColors.mutedText)
            }
            .padding()
            .background(KHOIColors.cardBackground)
            .cornerRadius(12)
        }
        .sheet(isPresented: $showPermissionSheet) {
            NotificationPermissionView(isPresented: $showPermissionSheet)
        }
    }
    
    private var statusText: String {
        switch notificationService.authorizationStatus {
        case .authorized:
            return "Enabled"
        case .denied:
            return "Disabled"
        case .notDetermined:
            return "Not Set"
        default:
            return "Unknown"
        }
    }
    
    private func handleTap() {
        if notificationService.authorizationStatus == .denied {
            // Open system settings
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        } else if notificationService.authorizationStatus == .notDetermined {
            showPermissionSheet = true
        } else {
            // Already authorized, open settings
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NotificationPermissionView(isPresented: .constant(true))
}
