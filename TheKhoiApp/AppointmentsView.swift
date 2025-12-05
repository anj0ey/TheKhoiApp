//
//  AppointmentsView.swift
//  TheKhoiApp
//
//  Created by Anjo on 12/2/25.
//
import SwiftUI

struct AppointmentsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var bookingService = BookingService()
    
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    Text(authManager.isBusinessMode ? "SCHEDULE" : "APPOINTMENTS")
                        .font(KHOITheme.headline)
                        .foregroundColor(KHOIColors.mutedText)
                        .tracking(2)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Content
                    if bookingService.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if bookingService.appointments.isEmpty {
                        EmptyStateView(isBusiness: authManager.isBusinessMode)
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                ForEach(bookingService.appointments) { appointment in
                                    AppointmentCard(appointment: appointment, isBusiness: authManager.isBusinessMode)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .onAppear {
                if let uid = authManager.firebaseUID {
                    bookingService.fetchAppointments(userID: uid, isBusiness: authManager.isBusinessMode)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Appointment Card
struct AppointmentCard: View {
    let appointment: Appointment
    let isBusiness: Bool
    
    var statusColor: Color {
        Color(hex: appointment.status.color)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(appointment.serviceName)
                        .font(KHOITheme.headline)
                    
                    // If business, show Client Name. If client, show Artist Name.
                    Text(isBusiness ? "Client: \(appointment.clientName)" : "with \(appointment.artistName)")
                        .font(.caption)
                        .foregroundColor(KHOIColors.mutedText)
                }
                
                Spacer()
                
                Text(appointment.status.rawValue.uppercased())
                    .font(.caption).bold()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.1))
                    .foregroundColor(statusColor)
                    .cornerRadius(8)
            }
            
            Divider()
            
            HStack {
                Label(appointment.dateString, systemImage: "calendar")
                Spacer()
                Label(appointment.timeString, systemImage: "clock")
            }
            .font(.caption)
            .foregroundColor(KHOIColors.darkText)
            
            // Action Buttons (Only for Confirmed/Pending)
            if appointment.status == .pending || appointment.status == .confirmed {
                HStack(spacing: 12) {
                    Button("Reschedule") {}
                        .font(.caption).bold()
                        .foregroundColor(KHOIColors.darkText)
                    
                    Spacer()
                    
                    Button("Message") {
                        // Hook up to chat later
                    }
                    .font(.caption).bold()
                    .foregroundColor(KHOIColors.accentBrown)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 8)
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let isBusiness: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: isBusiness ? "calendar.badge.exclamationmark" : "calendar.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(KHOIColors.mutedText)
            
            Text(isBusiness ? "No upcoming appointments" : "You haven't booked anything yet.")
                .font(KHOITheme.body)
                .foregroundColor(KHOIColors.mutedText)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
