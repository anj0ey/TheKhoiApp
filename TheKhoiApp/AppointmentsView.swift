//
//  AppointmentsView.swift
//  TheKhoiApp
//
//  Appointments view for both clients and business pros
//

import SwiftUI

struct AppointmentsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var bookingService = BookingService()
    
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(authManager.isBusinessMode ? "SCHEDULE" : "APPOINTMENTS")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(2)
                        .foregroundColor(KHOIColors.mutedText)
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                    
                    if authManager.isBusinessMode {
                        ProScheduleView(bookingService: bookingService)
                    } else {
                        ClientAppointmentsView(bookingService: bookingService)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                guard let userId = authManager.firebaseUID else { return }
                if authManager.isBusinessMode {
                    bookingService.fetchArtistAppointments(artistId: userId)
                } else {
                    bookingService.fetchClientAppointments(clientId: userId)
                }
            }
        }
    }
}

// MARK: - Client View

struct ClientAppointmentsView: View {
    @ObservedObject var bookingService: BookingService
    @State private var selectedTab = "Upcoming"
    
    var upcomingAppointments: [Appointment] {
        bookingService.clientAppointments.filter {
            $0.date >= Date() && ($0.status == .pending || $0.status == .confirmed)
        }
    }
    
    var pastAppointments: [Appointment] {
        bookingService.clientAppointments.filter {
            $0.date < Date() || $0.status == .completed || $0.status == .cancelled
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                AppointmentTabButton(title: "Upcoming", isSelected: selectedTab == "Upcoming") { selectedTab = "Upcoming" }
                AppointmentTabButton(title: "Past", isSelected: selectedTab == "Past") { selectedTab = "Past" }
            }
            .padding()
            
            if bookingService.isLoading {
                Spacer()
                ProgressView().tint(KHOIColors.accentBrown)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        let appointments = selectedTab == "Upcoming" ? upcomingAppointments : pastAppointments
                        if appointments.isEmpty {
                            EmptyStateView(icon: "calendar", title: "No \(selectedTab.lowercased()) appointments", subtitle: "Your appointments will appear here")
                                .padding(.top, 60)
                        } else {
                            ForEach(appointments) { apt in
                                ClientAppointmentCard(appointment: apt)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Pro Schedule View

struct ProScheduleView: View {
    @ObservedObject var bookingService: BookingService
    @State private var selectedDate: Date = Date()
    
    var todaysAppointments: [Appointment] {
        bookingService.artistAppointments.filter {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate) &&
            ($0.status == .pending || $0.status == .confirmed)
        }.sorted { $0.timeSlot < $1.timeSlot }
    }
    
    var pendingCount: Int {
        bookingService.artistAppointments.filter { $0.status == .pending }.count
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stats
                HStack(spacing: 12) {
                    StatCard(title: "Today", value: "\(todaysAppointments.count)", color: KHOIColors.accentBrown)
                    StatCard(title: "Pending", value: "\(pendingCount)", color: .orange)
                }
                .padding(.horizontal)
                
                // Date strip
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<14, id: \.self) { offset in
                            let date = Calendar.current.date(byAdding: .day, value: offset, to: Date())!
                            ScheduleDatePill(
                                date: date,
                                isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                                hasAppointments: hasAppointments(on: date)
                            ) { selectedDate = date }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Schedule header
                HStack {
                    Text(Calendar.current.isDateInToday(selectedDate) ? "TODAY'S SCHEDULE" : selectedDate.formatted(.dateTime.weekday(.wide)).uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(KHOIColors.mutedText)
                    Spacer()
                }
                .padding(.horizontal)
                
                // Appointments
                if todaysAppointments.isEmpty {
                    EmptyDayView()
                        .padding(.horizontal)
                } else {
                    ForEach(todaysAppointments) { apt in
                        ProAppointmentCard(
                            appointment: apt,
                            onConfirm: { bookingService.updateAppointmentStatus(appointmentId: apt.id, status: .confirmed) { _ in } },
                            onCancel: { bookingService.cancelAppointment(appointmentId: apt.id, reason: "Cancelled") { _ in } }
                        )
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    private func hasAppointments(on date: Date) -> Bool {
        bookingService.artistAppointments.contains {
            Calendar.current.isDate($0.date, inSameDayAs: date) && ($0.status == .pending || $0.status == .confirmed)
        }
    }
}

// MARK: - Supporting Components

struct AppointmentTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .tracking(1)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.white : Color.clear)
                .foregroundColor(isSelected ? KHOIColors.darkText : KHOIColors.mutedText)
                .cornerRadius(12)
                .shadow(color: isSelected ? Color.black.opacity(0.05) : .clear, radius: 5)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(KHOIColors.mutedText)
            Text(value).font(.system(size: 28, weight: .bold)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}

struct ScheduleDatePill: View {
    let date: Date
    let isSelected: Bool
    let hasAppointments: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.weekday(.abbreviated))).font(.system(size: 10, weight: .medium))
                Text(date.formatted(.dateTime.day())).font(.system(size: 16, weight: .bold))
                Circle().fill(hasAppointments ? KHOIColors.accentBrown : Color.clear).frame(width: 4, height: 4)
            }
            .frame(width: 44, height: 64)
            .background(isSelected ? KHOIColors.darkText : Color.clear)
            .foregroundColor(isSelected ? .white : KHOIColors.darkText)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.clear : Color.gray.opacity(0.15), lineWidth: 1))
        }
    }
}

struct ClientAppointmentCard: View {
    let appointment: Appointment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appointment.serviceName).font(.system(size: 16, weight: .semibold))
                    Text("with \(appointment.artistName)").font(.system(size: 13)).foregroundColor(KHOIColors.mutedText)
                }
                Spacer()
                Text(appointment.status.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color(hex: appointment.status.color).opacity(0.15))
                    .foregroundColor(Color(hex: appointment.status.color))
                    .cornerRadius(8)
            }
            Divider()
            HStack(spacing: 24) {
                Label(appointment.formattedShortDate, systemImage: "calendar").font(.system(size: 13, weight: .medium))
                Label(appointment.timeSlot, systemImage: "clock").font(.system(size: 13, weight: .medium))
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 8)
    }
}

struct ProAppointmentCard: View {
    let appointment: Appointment
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(appointment.timeSlot).font(.system(size: 13, weight: .bold)).foregroundColor(KHOIColors.accentBrown)
                Rectangle().fill(KHOIColors.accentBrown.opacity(0.3)).frame(height: 1)
            }
            .padding(.bottom, 8)
            
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: appointment.clientProfileImageURL ?? "")) { img in
                    img.resizable().scaledToFill()
                } placeholder: { Circle().fill(Color.gray.opacity(0.2)) }
                .frame(width: 50, height: 50).clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(appointment.clientName).font(.system(size: 15, weight: .semibold))
                    Text(appointment.serviceName).font(.system(size: 13)).foregroundColor(KHOIColors.mutedText)
                    HStack(spacing: 8) {
                        Text("\(appointment.serviceDuration) min").font(.system(size: 11)).foregroundColor(KHOIColors.mutedText)
                        Text("•").foregroundColor(KHOIColors.mutedText)
                        Text(appointment.formattedPrice).font(.system(size: 11, weight: .semibold)).foregroundColor(KHOIColors.accentBrown)
                    }
                }
                Spacer()
                
                if appointment.status == .pending {
                    VStack(spacing: 6) {
                        Button(action: onConfirm) { Image(systemName: "checkmark.circle.fill").font(.system(size: 28)).foregroundColor(.green) }
                        Button(action: onCancel) { Image(systemName: "xmark.circle.fill").font(.system(size: 28)).foregroundColor(.red.opacity(0.7)) }
                    }
                } else {
                    Text("Confirmed").font(.system(size: 11, weight: .semibold)).foregroundColor(.green)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(Color.green.opacity(0.1)).cornerRadius(6)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 48)).foregroundColor(KHOIColors.mutedText.opacity(0.4))
            Text(title).font(.system(size: 16, weight: .semibold))
            Text(subtitle).font(.system(size: 13)).foregroundColor(KHOIColors.mutedText)
        }
        .frame(maxWidth: .infinity)
    }
}

struct EmptyDayView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sun.max").font(.system(size: 36)).foregroundColor(KHOIColors.softBrown)
            Text("No appointments").font(.system(size: 14, weight: .medium))
            Text("Enjoy your free time!").font(.system(size: 12)).foregroundColor(KHOIColors.mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color.white)
        .cornerRadius(12)
    }
}
