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
        GeometryReader { geo in
            ZStack {
                Color(hex:"FEFCF6")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Image("enable notifications")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width,
                               height: geo.size.height * 0.62)
                        .clipped()
                        .scaleEffect(2.2)
                        //.offset(y: 22)
                        .ignoresSafeArea(edges: .top)
                   
                    Spacer(minLength: geo.size.height * 0.05)  // 5% of screen height

                    VStack(spacing: 10) {
                        Text("Your glow-up doesn’t clock out.")
                            .font(KHOITheme.title.bold())
                            .foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.15))
                            .multilineTextAlignment(.center)

                        Text("Never miss your booking reminders\nand messages.")
                            .font(KHOITheme.headline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, geo.size.height * 0.05)  // 10% of screen height
                    .padding(.horizontal, 32)

                    // Buttons (bring up)
                    VStack(spacing: 10) {
                        Button(action: enableNotifications) {
                            Text("Turn on notifications")
                                .font(KHOITheme.headline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(KHOIColors.accentBrown)
                                .cornerRadius(12)
                        }

                        Button(action: skipNotifications) {
                            Text("Another time")
                                .font(KHOITheme.headline)
                                .foregroundColor(.gray)
                                .padding(.vertical, 10)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 18)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 14)

                    Spacer(minLength: 0)
                }
            }
        }
    }
    
    // MARK: - Actions
    
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
