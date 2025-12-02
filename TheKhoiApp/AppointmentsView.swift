//
//  AppointmentsView.swift
//  TheKhoiApp
//
//  Created by Anjo on 12/2/25.
//

import SwiftUI

struct Appointments: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var appointmentService = AppointmentService()
    @State private var showNewBookingSheet = false
    @State private var selectedSegment = 0 // 0: Upcoming, 1: Past
    
    var filteredAppointments: [Appointment] {
        let now = Date()
        if selectedSegment == 0 {
            // Upcoming: Future dates OR Status is upcoming
            return appointmentService.appointments.filter {
                ($0.date >= now || $0.status == .upcoming) && $0.status != .cancelled && $0.status != .completed
            }
        } else {
            // Past: History or Cancelled
            return appointmentService.appointments.filter {
                $0.date < now || $0.status == .completed || $0.status == .cancelled
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Segmented Control
                    Picker("Filter", selection: $selectedSegment) {
                        Text("Upcoming").tag(0)
                        Text("History").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    .onAppear {
                        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(KHOIColors.accentBrown)
                        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
                    }
                    
                    if appointmentService.isLoading {
                        Spacer()
                        ProgressView()
                            .tint(KHOIColors.accentBrown)
                        Spacer()
                    } else if filteredAppointments.isEmpty {
                        EmptyStateView(tab: selectedSegment)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredAppointments) { appointment in
                                    AppointmentCard(appointment: appointment) {
                                        if appointment.status == .upcoming {
                                            appointmentService.cancelAppointment(appointmentId: appointment.id)
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Appointments")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showNewBookingSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(KHOIColors.accentBrown)
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showNewBookingSheet) {
                NewBookingSheet(isPresented: $showNewBookingSheet)
                    .environmentObject(authManager)
                    .environmentObject(appointmentService)
            }
            .onAppear {
                if let uid = authManager.firebaseUID {
                    appointmentService.listenToAppointments(userId: uid)
                }
            }
        }
    }
}

// MARK: - Subviews

struct AppointmentCard: View {
    let appointment: Appointment
    var onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                // Service Icon / Initial
                Circle()
                    .fill(Color(hex: getServiceColor(appointment.serviceType)))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(appointment.serviceType.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(appointment.serviceType)
                        .font(.headline)
                        .foregroundColor(KHOIColors.darkText)
                    
                    Text(appointment.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(KHOIColors.accentBrown)
                }
                
                Spacer()
                
                Text(appointment.status.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: appointment.status.color).opacity(0.1))
                    .foregroundColor(Color(hex: appointment.status.color))
                    .clipShape(Capsule())
            }
            
            if !appointment.notes.isEmpty {
                Text(appointment.notes)
                    .font(.caption)
                    .foregroundColor(KHOIColors.mutedText)
                    .padding(.top, 4)
            }
            
            if appointment.status == .upcoming {
                Divider().padding(.vertical, 4)
                Button(action: onCancel) {
                    HStack {
                        Spacer()
                        Text("Cancel Appointment").font(.caption).foregroundColor(.red.opacity(0.8))
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(KHOIColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    func getServiceColor(_ service: String) -> String {
        return ChatTag(rawValue: service)?.color ?? "8B7355"
    }
}

struct EmptyStateView: View {
    let tab: Int
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: tab == 0 ? "calendar.badge.plus" : "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(KHOIColors.softBrown.opacity(0.5))
            Text(tab == 0 ? "No upcoming appointments" : "No appointment history")
                .font(.title3)
                .foregroundColor(KHOIColors.darkText)
            Spacer()
        }
    }
}

struct NewBookingSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appointmentService: AppointmentService
    
    @State private var selectedService: ChatTag = .nails
    @State private var selectedDate = Date().addingTimeInterval(86400)
    @State private var notes = ""
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background.ignoresSafeArea()
                Form {
                    Section(header: Text("Service Details").foregroundColor(KHOIColors.accentBrown)) {
                        Picker("Service", selection: $selectedService) {
                            ForEach(ChatTag.allCases, id: \.self) { tag in
                                Text(tag.rawValue).tag(tag)
                            }
                        }
                        DatePicker("Date & Time", selection: $selectedDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                            .tint(KHOIColors.accentBrown)
                    }
                    Section(header: Text("Additional Info").foregroundColor(KHOIColors.accentBrown)) {
                        TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...6)
                    }
                    Section {
                        Button(action: submitBooking) {
                            HStack {
                                Spacer()
                                if isSubmitting { ProgressView() } else { Text("Confirm Booking").fontWeight(.semibold) }
                                Spacer()
                            }
                        }
                        .disabled(isSubmitting)
                        .listRowBackground(KHOIColors.accentBrown)
                        .foregroundColor(.white)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Booking")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isPresented = false }.foregroundColor(KHOIColors.darkText)
                }
            }
        }
    }
    
    func submitBooking() {
        guard let uid = authManager.firebaseUID else { return }
        isSubmitting = true
        let newAppointment = Appointment(userId: uid, serviceType: selectedService.rawValue, date: selectedDate, notes: notes)
        appointmentService.bookAppointment(appointment: newAppointment) { result in
            isSubmitting = false
            if case .success = result { isPresented = false }
        }
    }
}
