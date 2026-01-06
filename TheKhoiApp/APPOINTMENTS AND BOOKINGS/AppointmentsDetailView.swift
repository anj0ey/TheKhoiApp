//
//  AppointmentDetailView.swift
//  TheKhoiApp
//
//

import SwiftUI

struct AppointmentDetailView: View {
    let appointment: Appointment
    let isProView: Bool  // True if viewing as professional, false if client
    
    @Environment(\.dismiss) var dismiss
    @State private var showCancelAlert = false
    @State private var cancelReason = ""
    @StateObject private var bookingService = BookingService()
    
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Status badge at top
                        statusBadge
                        
                        // Avatar overlap
                        avatarSection
                        
                        // Service summary card
                        serviceSummaryCard
                        
                        // Special requests (only if filled in)
                        if !appointment.specialRequests.isEmpty {
                            specialRequestsSection
                        }
                        
                        // Inspo images (only if any uploaded)
                        if !appointment.inspoImages.isEmpty {
                            inspoImagesSection
                        }
                        
                        // Contact info section
                        contactInfoSection
                        
                        // Action buttons (if applicable)
                        if appointment.status == .pending || appointment.status == .confirmed {
                            actionButtons
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {                
                ToolbarItem(placement: .principal) {
                    Text("APPOINTMENT")
                        .font(KHOITheme.headline)
                        .tracking(2)
                        .foregroundColor(KHOIColors.mutedText)
                }
            }
            .alert("Cancel Appointment", isPresented: $showCancelAlert) {
                TextField("Reason (optional)", text: $cancelReason)
                Button("Keep Appointment", role: .cancel) { }
                Button("Cancel Appointment", role: .destructive) {
                    cancelAppointment()
                }
            } message: {
                Text("Are you sure you want to cancel this appointment?")
            }
        }
    }
    
    // MARK: - Status Badge
    
    private var statusBadge: some View {
        HStack {
            Spacer()
            Text(appointment.status.displayName)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(hex: appointment.status.color).opacity(0.15))
                .foregroundColor(Color(hex: appointment.status.color))
                .cornerRadius(20)
            Spacer()
        }
        .padding(.top, 8)
    }
    
    // MARK: - Avatar Section
    
    private var avatarSection: some View {
        VStack(spacing: 8) {
            ZStack {
                // Client avatar
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .overlay(
                        AsyncImage(url: URL(string: appointment.clientProfileImageURL ?? "")) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                        .clipShape(Circle())
                    )
                    .offset(x: -25)
                
                // Artist avatar
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .overlay(
                        AsyncImage(url: URL(string: appointment.artistProfileImageURL ?? "")) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                        .clipShape(Circle())
                    )
                    .overlay(Circle().stroke(KHOIColors.background, lineWidth: 4))
                    .offset(x: 25)
            }
            
            // Caption based on who's viewing
            if isProView {
                Text("appointment with \(appointment.clientName)")
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.mutedText)
            } else {
                Text("your appointment with \(appointment.artistName)")
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.mutedText)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Service Summary Card
    
    private var serviceSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Service name and price
            HStack {
                Text(appointment.serviceName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(KHOIColors.darkText)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(appointment.formattedPrice)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(KHOIColors.accentBrown)
                    Text("/ \(appointment.serviceDuration) min")
                        .font(.system(size: 12))
                        .foregroundColor(KHOIColors.mutedText)
                }
            }
            
            // Service description (if available)
            if !appointment.serviceDescription.isEmpty {
                Text(appointment.serviceDescription)
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.mutedText)
                    .lineLimit(3)
            }
            
            Divider()
            
            // Date
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundColor(KHOIColors.darkText)
                Text(appointment.formattedDate)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(KHOIColors.darkText)
            }
            
            // Time
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .foregroundColor(KHOIColors.darkText)
                Text("\(appointment.timeSlot) TO \(appointment.endTime)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(KHOIColors.darkText)
            }
            
            // Location
            if !appointment.artistLocation.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle")
                        .foregroundColor(KHOIColors.darkText)
                    Text(appointment.artistLocation)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(KHOIColors.darkText)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10)
        .padding(.horizontal)
    }
    
    // MARK: - Special Requests Section
    
    private var specialRequestsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SPECIAL REQUESTS")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.5)
                .foregroundColor(KHOIColors.mutedText)
            
            Text(appointment.specialRequests)
                .font(KHOITheme.body)
                .foregroundColor(KHOIColors.darkText)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Inspo Images Section
    
    private var inspoImagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INSPIRATION IMAGES")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.5)
                .foregroundColor(KHOIColors.mutedText)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(appointment.inspoImages, id: \.self) { imageUrl in
                        AsyncImage(url: URL(string: imageUrl)) { phase in
                            switch phase {
                            case .empty:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(ProgressView().scaleEffect(0.7))
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(KHOIColors.mutedText)
                                    )
                            @unknown default:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                            }
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Contact Info Section
    
    private var contactInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isProView ? "CLIENT INFORMATION" : "YOUR INFORMATION")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.5)
                .foregroundColor(KHOIColors.mutedText)
            
            VStack(spacing: 8) {
                if isProView {
                    // Show client info to pro
                    InfoRowDisplay(label: "Name:", value: appointment.clientName)
                    InfoRowDisplay(label: "Email:", value: appointment.clientEmail)
                    if !appointment.clientPhone.isEmpty {
                        InfoRowDisplay(label: "Phone:", value: appointment.clientPhone)
                    }
                } else {
                    // Show client's own info
                    let nameParts = appointment.clientName.components(separatedBy: " ")
                    InfoRowDisplay(label: "First Name:", value: nameParts.first ?? "")
                    InfoRowDisplay(label: "Last Name:", value: nameParts.dropFirst().joined(separator: " "))
                    InfoRowDisplay(label: "Email:", value: appointment.clientEmail)
                    if !appointment.clientPhone.isEmpty {
                        InfoRowDisplay(label: "Phone:", value: appointment.clientPhone)
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if isProView && appointment.status == .pending {
                // Pro can confirm or cancel
                Button(action: confirmAppointment) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Confirm Appointment")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .cornerRadius(12)
                }
                
                Button(action: { showCancelAlert = true }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Decline Appointment")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
            } else if appointment.status == .confirmed || appointment.status == .pending {
                // Both can cancel confirmed appointments
                Button(action: { showCancelAlert = true }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Cancel Appointment")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Actions
    
    private func confirmAppointment() {
        bookingService.updateAppointmentStatus(
            appointmentId: appointment.id,
            status: .confirmed
        ) { result in
            if case .success = result {
                dismiss()
            }
        }
    }
    
    private func cancelAppointment() {
        bookingService.cancelAppointment(
            appointmentId: appointment.id,
            reason: cancelReason.isEmpty ? "Cancelled" : cancelReason
        ) { result in
            if case .success = result {
                dismiss()
            }
        }
    }
}

// MARK: - Info Row Display (Read-only version)

struct InfoRowDisplay: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(KHOIColors.mutedText)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(KHOIColors.darkText)
        }
    }
}

// MARK: - Preview

#Preview {
    AppointmentDetailView(
        appointment: Appointment(
            clientId: "123",
            clientName: "Jane Doe",
            clientEmail: "jane@example.com",
            clientPhone: "(555) 123-4567",
            artistId: "456",
            artistName: "Sarah Beauty",
            artistLocation: "Los Angeles, CA",
            serviceId: "789",
            serviceName: "Bridal Glam Makeup",
            serviceCategory: "Makeup",
            servicePrice: 150,
            serviceDuration: 90,
            serviceDescription: "Full glam bridal makeup with lashes included",
            date: Date(),
            timeSlot: "10:00 AM",
            endTime: "11:30 AM",
            status: .confirmed,
            inspoImages: ["https://example.com/img1.jpg", "https://example.com/img2.jpg"],
            specialRequests: "I prefer a natural look with soft pink tones. Allergic to latex."
        ),
        isProView: false
    )
}
