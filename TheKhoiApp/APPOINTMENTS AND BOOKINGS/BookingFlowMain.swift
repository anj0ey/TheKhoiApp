//
//  BookingFlowView.swift
//  TheKhoiApp
//
//  Multi-step booking flow for clients to book appointments
//

import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseFirestore

struct BookingFlowView: View {
    let artist: Artist
    @Binding var isPresented: Bool
    @EnvironmentObject var authManager: AuthManager
    
    @StateObject private var bookingService = BookingService()
    @StateObject private var bookingState = BookingState()
    
    @State private var currentStep = 1
    @State private var showConfirmation = false
    @State private var isSubmitting = false
    @State private var bookedSlots: [String] = []
    
    @State private var artistAvailability: BusinessAvailability? = nil
    
    var body: some View {
        ZStack {
            KHOIColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                bookingHeader
                
                // Content
                TabView(selection: $currentStep) {
                    serviceSelectionStep.tag(1)
                    serviceDetailsStep.tag(2)
                    dateTimeStep.tag(3)
                    inspoUploadStep.tag(4)
                    summaryStep.tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
            }
            
            // Confirmation overlay
            if showConfirmation {
                confirmationView
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .onAppear {
            fetchArtistAvailability()
        }
    }
    
    // MARK: - Header
    
    private var bookingHeader: some View {
        HStack {
            Button(action: handleBack) {
                Image(systemName: currentStep > 1 ? "chevron.left" : "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(KHOIColors.darkText)
            }
            
            Spacer()
            
            Text(artist.displayHandle)
                .font(KHOITheme.headline)
                .foregroundColor(KHOIColors.darkText)
            
            Spacer()

        }
        .padding()
        .background(KHOIColors.background)
    }
    
    // MARK: - Step 1: Service Selection
    
    private var serviceSelectionStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Section header
                VStack(alignment: .leading, spacing: 4) {
                    Text("SERVICES")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1)
                        .foregroundColor(KHOIColors.darkText)
                    
                    Text("Select service")
                        .font(KHOITheme.caption)
                        .foregroundColor(KHOIColors.mutedText)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Service cards - only show detailed services (no fallback)
                if artist.hasDetailedServices {
                    ForEach(artist.servicesDetailed) { service in
                        BookingServiceCard(
                            service: service,
                            portfolioImage: artist.portfolioImagesForCategory(service.category).first
                        ) {
                            bookingState.selectedService = service
                            withAnimation { currentStep = 2 }
                        }
                        .padding(.horizontal)
                    }
                } else {
                    // Empty state - should not happen if booking flow is only accessible when hasDetailedServices
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundColor(KHOIColors.mutedText.opacity(0.5))
                        Text("No services available")
                            .font(KHOITheme.body)
                            .foregroundColor(KHOIColors.mutedText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                }
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Step 2: Service Details
    
    private var serviceDetailsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let service = bookingState.selectedService {
                    // Section header
                    Text("SERVICES")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1)
                        .foregroundColor(KHOIColors.darkText)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    // Portfolio grid
                    let images = artist.portfolioImagesForCategory( service.category)
                    PortfolioGridView(images: images)
                        .padding(.top, 12)
                    
                    // Service info
                    VStack(alignment: .leading, spacing: 16) {
                        // Name and price
                        HStack(alignment: .top) {
                            Text(service.name)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(KHOIColors.darkText)
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Text("$\(Int(service.price))")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(KHOIColors.accentBrown)
                                Text("/ \(service.duration) min")
                                    .font(.system(size: 14))
                                    .foregroundColor(KHOIColors.mutedText)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        
                        // Description
                        if !service.description.isEmpty {
                            Text(service.description)
                                .font(KHOITheme.body)
                                .foregroundColor(KHOIColors.darkText)
                                .lineSpacing(4)
                                .padding(.horizontal)
                        }
                        
                        // What to know section
                        if let policies = artist.policies {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("What to Know Beforehand")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(KHOIColors.darkText)
                                    .padding(.top, 8)
                                
                                if !policies.lateArrivalPolicy.isEmpty {
                                    PolicyInfoRow(
                                        icon: "person.crop.circle.badge.checkmark",
                                        title: "ARRIVAL",
                                        content: policies.lateArrivalPolicy
                                    )
                                }
                                
                                if !policies.additionalNotes.isEmpty {
                                    PolicyInfoRow(
                                        icon: "paintbrush",
                                        title: "CUSTOMIZATION",
                                        content: policies.additionalNotes
                                    )
                                }
                            }
                            .padding(.horizontal)
                            
                            // Reservation Policies
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Reservation Policies")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(KHOIColors.darkText)
                                    .padding(.top, 16)
                                
                                if !policies.cancellationPolicy.isEmpty {
                                    PolicyInfoRow(
                                        icon: "calendar.badge.minus",
                                        title: "CANCELLATION POLICY",
                                        content: policies.cancellationPolicy
                                    )
                                }
                                
                                PolicyInfoRow(
                                    icon: "clock",
                                    title: "ON-TIME POLICY",
                                    content: "Please show up on time! Late arrivals may result in shortened service time or rescheduling."
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        // Explore More section
                        if artist.servicesDetailed.count > 1 {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("EXPLORE MORE")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.5)
                                    .foregroundColor(KHOIColors.mutedText)
                                    .padding(.top, 24)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(artist.servicesDetailed.filter { $0.id != service.id }) { otherService in
                                            ExploreServiceCard(
                                                service: otherService,
                                                image: artist.portfolioImagesForCategory(otherService.category).first
                                            ) {
                                                bookingState.selectedService = otherService
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Confirm button
                    Button(action: {
                        fetchBookedSlots()
                        withAnimation { currentStep = 3 }
                    }) {
                        Text("Confirm Service")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(KHOIColors.darkText)
                            .cornerRadius(12)
                    }
                    .padding()
                    .padding(.top, 16)
                }
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Step 3: Date & Time
    
    private var dateTimeStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with selected date
                VStack(alignment: .leading, spacing: 4) {
                    Text("DATE & TIME")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1)
                        .foregroundColor(KHOIColors.darkText)
                    
                    Text(formatSelectedDateTime())
                        .font(KHOITheme.caption)
                        .foregroundColor(KHOIColors.mutedText)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Date strip
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<14) { index in
                            let date = Calendar.current.date(byAdding: .day, value: index, to: Date())!
                            let isSelected = Calendar.current.isDate(date, inSameDayAs: bookingState.selectedDate)
                            let dateAvailable = isDateAvailable(date)  // CHECK AVAILABILITY
                            
                            DatePill(date: date, isSelected: isSelected, isAvailable: dateAvailable) {
                                // Only allow selection if date is available
                                if dateAvailable {
                                    bookingState.selectedDate = date
                                    bookingState.selectedTimeSlot = nil
                                    fetchBookedSlots()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Check if artist is closed on selected day
                if let avail = artistAvailability?.availability(for: bookingState.selectedDate), !avail.isOpen {
                    // Artist is closed - show message instead of time slots
                    VStack(spacing: 16) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 40))
                            .foregroundColor(KHOIColors.mutedText)
                        
                        Text("\(artist.fullName) is not available on this day")
                            .font(KHOITheme.body)
                            .foregroundColor(KHOIColors.mutedText)
                            .multilineTextAlignment(.center)
                        
                        Text("Please select another date")
                            .font(KHOITheme.caption)
                            .foregroundColor(KHOIColors.mutedText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .padding(.horizontal)
                } else {
                    // Morning slots
                    TimeSlotSection(
                        title: "MORNING",
                        subtitle: "(before 11:45 AM)",
                        icon: "sun.max",
                        slots: generateTimeSlots(start: 10, end: 12),
                        bookedSlots: bookedSlots,
                        selectedSlot: bookingState.selectedTimeSlot
                    ) { slot in
                        bookingState.selectedTimeSlot = slot
                    }
                    
                    // Afternoon slots
                    TimeSlotSection(
                        title: "AFTERNOON",
                        subtitle: "(12:00 PM - 4:45 PM)",
                        icon: "sun.min",
                        slots: generateTimeSlots(start: 12, end: 17),
                        bookedSlots: bookedSlots,
                        selectedSlot: bookingState.selectedTimeSlot
                    ) { slot in
                        bookingState.selectedTimeSlot = slot
                    }
                    
                    // Evening slots
                    TimeSlotSection(
                        title: "EVENING",
                        subtitle: "(After 5:00PM)",
                        icon: "moon",
                        slots: generateTimeSlots(start: 17, end: 19),
                        bookedSlots: bookedSlots,
                        selectedSlot: bookingState.selectedTimeSlot
                    ) { slot in
                        bookingState.selectedTimeSlot = slot
                    }
                }
                
                // Upload Inspo section header
                Text("UPLOAD INSPO")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1)
                    .foregroundColor(KHOIColors.darkText)
                    .padding(.horizontal)
                    .padding(.top, 16)
                
                // Inspo grid
                InspoUploadGrid(images: $bookingState.inspoImages)
                    .padding(.horizontal)
                
                // Confirm button
                Button(action: {
                    withAnimation { currentStep = 4 }
                }) {
                    Text("Confirm Info.")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(bookingState.selectedTimeSlot != nil ? KHOIColors.darkText : Color.gray.opacity(0.4))
                        .cornerRadius(12)
                }
                .disabled(bookingState.selectedTimeSlot == nil)
                .padding()
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Step 4: Inspo Upload (Combined with step 3, but keeping for flow)
    
    private var inspoUploadStep: some View {
        summaryStep
    }
    
    // MARK: - Step 5: Summary
    
    private var summaryStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                Text("SUMMARY")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1)
                    .foregroundColor(KHOIColors.darkText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Avatar overlap
                ZStack {
                    // Client avatar
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .overlay(
                            AsyncImage(url: URL(string: authManager.currentUser?.profileImageURL ?? "")) { image in
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
                            AsyncImage(url: URL(string: artist.profileImageURL ?? "")) { image in
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
                .padding(.top, 8)
                
                Text("you are booking with \(artist.fullName)")
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.mutedText)
                
                // Service summary card
                if let service = bookingState.selectedService {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(service.name)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(KHOIColors.darkText)
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Text("$\(Int(service.price))")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(KHOIColors.accentBrown)
                                Text("/ \(service.duration) min")
                                    .font(.system(size: 12))
                                    .foregroundColor(KHOIColors.mutedText)
                            }
                        }
                        
                        if !service.description.isEmpty {
                            Text(service.description)
                                .font(KHOITheme.caption)
                                .foregroundColor(KHOIColors.mutedText)
                                .lineLimit(3)
                        }
                        
                        Divider()
                        
                        // Date
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .foregroundColor(KHOIColors.darkText)
                            Text(bookingState.selectedDate.formatted(date: .long, time: .omitted))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(KHOIColors.darkText)
                        }
                        
                        // Time
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .foregroundColor(KHOIColors.darkText)
                            Text("\(bookingState.selectedTimeSlot?.time ?? "") TO \(bookingState.endTime)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(KHOIColors.darkText)
                        }
                        
                        // Location note
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle")
                                .foregroundColor(KHOIColors.darkText)
                            Text("LOCATION WILL BE MESSAGED TO YOU AFTER CONFIRMING THIS BOOKING")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(KHOIColors.mutedText)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 10)
                    .padding(.horizontal)
                }
                
                // Special requests
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Any special requests?")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(KHOIColors.darkText)
                        Spacer()
                        Text("(Optional)")
                            .font(KHOITheme.caption)
                            .foregroundColor(KHOIColors.mutedText)
                    }
                    
                    TextField("Share your ideas, likes, dislikes, favorite brands, or anything I should know to make your experience better.", text: $bookingState.specialRequests, axis: .vertical)
                        .font(KHOITheme.caption)
                        .lineLimit(4...6)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    
                    Text("\(bookingState.specialRequests.count) / 1000 characters")
                        .font(.system(size: 10))
                        .foregroundColor(KHOIColors.mutedText)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal)
                
                // Your Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("YOUR INFORMATION")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(KHOIColors.darkText)
                    
                    InfoRow(label: "First Name:", value: authManager.currentUser?.fullName.components(separatedBy: " ").first ?? "")
                    InfoRow(label: "Last Name:", value: authManager.currentUser?.fullName.components(separatedBy: " ").dropFirst().joined(separator: " ") ?? "")
                    InfoRow(label: "Email Address:", value: authManager.currentUser?.email ?? "")
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Text Notifications
                VStack(alignment: .leading, spacing: 12) {
                    Text("Text Notifications")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(KHOIColors.darkText)
                    
                    TextField("(123) 456 - 7890", text: $bookingState.clientPhone)
                        .font(KHOITheme.body)
                        .keyboardType(.phonePad)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    
                    Toggle(isOn: $bookingState.textNotifications) {
                        Text("Yes, please send me text message reminders about my upcoming appointment.")
                            .font(.system(size: 12))
                            .foregroundColor(KHOIColors.mutedText)
                    }
                    .toggleStyle(CheckboxToggleStyle())
                }
                .padding(.horizontal)
                
                // Confirm button
                Button(action: submitBooking) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Confirm Booking")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(KHOIColors.darkText)
                .cornerRadius(12)
                .disabled(isSubmitting)
                .padding()
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Confirmation View
    
    private var confirmationView: some View {
        ZStack {
            KHOIColors.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Balloon/heart image
                Image("free use")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                
                VStack(spacing: 8) {
                    Text("self-care is the best care.")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(KHOIColors.darkText)
                    
                    Text("your appointment has been booked!")
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.mutedText)
                }
                
                Spacer()
                
                Button(action: {
                    isPresented = false
                }) {
                    Text("Back to Home")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(KHOIColors.darkText)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(KHOIColors.darkText, lineWidth: 1)
                        )
                }
                .padding(.bottom, 60)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func handleBack() {
        if currentStep > 1 {
            withAnimation { currentStep -= 1 }
        } else {
            isPresented = false
        }
    }
    
    private func formatSelectedDateTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        var result = formatter.string(from: bookingState.selectedDate)
        if let slot = bookingState.selectedTimeSlot {
            result += " at \(slot.time)"
        }
        return result
    }
    
    private func fetchBookedSlots() {
        bookingService.getBookedSlots(artistId: artist.id, date: bookingState.selectedDate) { slots in
            self.bookedSlots = slots
        }
    }
    
    private func isDateAvailable(_ date: Date) -> Bool {
        guard let availability = artistAvailability else { return true }
        return availability.availability(for: date).isOpen
    }
    
    private func fetchArtistAvailability() {
        let db = Firestore.firestore()
        
        // First try artists collection
        db.collection("artists").document(artist.id).getDocument { snapshot, error in
            if let data = snapshot?.data(),
               let availData = data["availability"] as? [String: Any] {
                self.artistAvailability = BusinessAvailability.fromFirestore(availData)
            } else {
                // Try pro_applications collection
                db.collection("pro_applications").document(artist.id).getDocument { snapshot, _ in
                    if let data = snapshot?.data(),
                       let availData = data["availability"] as? [String: Any] {
                        self.artistAvailability = BusinessAvailability.fromFirestore(availData)
                    }
                }
            }
        }
    }
    
    private func generateTimeSlots(start: Int, end: Int) -> [TimeSlot] {
        var slots: [TimeSlot] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        // Get availability for selected date
        let dayAvailability = artistAvailability?.availability(for: bookingState.selectedDate)
        
        for hour in start..<end {
            for minute in [0, 15, 30, 45] {
                var components = DateComponents()
                components.hour = hour
                components.minute = minute
                
                if let date = Calendar.current.date(from: components) {
                    let timeString = formatter.string(from: date)
                    
                    // Check if slot is within artist's availability
                    var isWithinAvailability = true
                    if let avail = dayAvailability {
                        if !avail.isOpen {
                            isWithinAvailability = false
                        } else {
                            let slotMinutes = hour * 60 + minute
                            let startMinutes = avail.startHour * 60 + avail.startMinute
                            let endMinutes = avail.endHour * 60 + avail.endMinute
                            isWithinAvailability = slotMinutes >= startMinutes && slotMinutes < endMinutes
                        }
                    }
                    
                    slots.append(TimeSlot(
                        time: timeString,
                        hour: hour,
                        minute: minute,
                        isAvailable: !bookedSlots.contains(timeString) && isWithinAvailability
                    ))
                }
            }
        }
        return slots
    }

    
    private func submitBooking() {
        guard let service = bookingState.selectedService,
              let timeSlot = bookingState.selectedTimeSlot,
              let user = authManager.currentUser else { return }
        
        isSubmitting = true
        
        let appointment = Appointment(
            clientId: user.id,
            clientName: user.fullName,
            clientEmail: user.email,
            clientPhone: bookingState.clientPhone,
            clientProfileImageURL: user.profileImageURL,
            artistId: artist.id,
            artistName: artist.fullName,
            artistProfileImageURL: artist.profileImageURL,
            artistLocation: artist.city,
            serviceId: service.id,
            serviceName: service.name,
            serviceCategory: service.category,
            servicePrice: service.price,
            serviceDuration: service.duration,
            serviceDescription: service.description,
            date: bookingState.appointmentDate,
            timeSlot: timeSlot.time,
            endTime: bookingState.endTime,
            status: .pending,
            inspoImages: bookingState.inspoImages,
            specialRequests: bookingState.specialRequests,
            textNotifications: bookingState.textNotifications,
            createdAt: Date()
        )
        
        bookingService.createAppointment(appointment) { result in
            isSubmitting = false
            switch result {
            case .success:
                withAnimation {
                    showConfirmation = true
                }
            case .failure(let error):
                print("Booking error: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct BookingServiceCard: View {
    let service: ServiceItem
    let portfolioImage: PortfolioImage?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Image
                if let image = portfolioImage {
                    AsyncImage(url: URL(string: image.url)) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.2))
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(service.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(KHOIColors.darkText)
                    
                    if !service.description.isEmpty {
                        Text(service.description)
                            .font(.system(size: 12))
                            .foregroundColor(KHOIColors.mutedText)
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 4) {
                        Text("$\(Int(service.price))")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(KHOIColors.accentBrown)
                        Text("/ \(service.duration) min")
                            .font(.system(size: 12))
                            .foregroundColor(KHOIColors.mutedText)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.03), radius: 8)
        }
    }
}

struct PortfolioGridView: View {
    let images: [PortfolioImage]
    
    var body: some View {
        if images.isEmpty {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 200)
                .padding(.horizontal)
        } else {
            let displayImages = Array(images.prefix(5))
            
            HStack(spacing: 4) {
                // Large image on left
                if let first = displayImages.first {
                    AsyncImage(url: URL(string: first.url)) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.2))
                    }
                    .frame(width: UIScreen.main.bounds.width * 0.5 - 20, height: 180)
                    .clipped()
                    .cornerRadius(8)
                }
                
                // Grid on right
                if displayImages.count > 1 {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            ForEach(displayImages.dropFirst().prefix(2)) { image in
                                AsyncImage(url: URL(string: image.url)) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    Rectangle().fill(Color.gray.opacity(0.2))
                                }
                                .frame(width: (UIScreen.main.bounds.width * 0.5 - 24) / 2, height: 88)
                                .clipped()
                                .cornerRadius(6)
                            }
                        }
                        
                        if displayImages.count > 3 {
                            HStack(spacing: 4) {
                                ForEach(displayImages.dropFirst(3).prefix(2)) { image in
                                    AsyncImage(url: URL(string: image.url)) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: {
                                        Rectangle().fill(Color.gray.opacity(0.2))
                                    }
                                    .frame(width: (UIScreen.main.bounds.width * 0.5 - 24) / 2, height: 88)
                                    .clipped()
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct PolicyInfoRow: View {
    let icon: String
    let title: String
    let content: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(KHOIColors.darkText)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(KHOIColors.darkText)
                
                Text(content)
                    .font(.system(size: 13))
                    .foregroundColor(KHOIColors.mutedText)
                    .lineSpacing(2)
            }
        }
    }
}

struct ExploreServiceCard: View {
    let service: ServiceItem
    let image: PortfolioImage?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Image
                if let img = image {
                    AsyncImage(url: URL(string: img.url)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.2))
                    }
                    .frame(width: 120, height: 80)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 120, height: 80)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(service.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(KHOIColors.darkText)
                        .lineLimit(1)
                    
                    Text(service.description)
                        .font(.system(size: 10))
                        .foregroundColor(KHOIColors.mutedText)
                        .lineLimit(2)
                    
                    HStack(spacing: 2) {
                        Text("$\(Int(service.price))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(KHOIColors.accentBrown)
                        Text("/ \(service.duration) min")
                            .font(.system(size: 10))
                            .foregroundColor(KHOIColors.mutedText)
                    }
                }
                .padding(8)
            }
            .frame(width: 120)
            .background(Color.white)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.05), radius: 4)
        }
    }
}

struct DatePill: View {
    let date: Date
    let isSelected: Bool
    var isAvailable: Bool = true
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(size: 10, weight: .medium))
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 16, weight: .bold))
                
                // Availability indicator
                Circle()
                    .fill(isAvailable ? (isSelected ? .white : KHOIColors.accentBrown) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(width: 48, height: 70)
            .background(isSelected ? KHOIColors.darkText : Color.clear)
            .foregroundColor(isSelected ? .white : (isAvailable ? KHOIColors.darkText : KHOIColors.mutedText))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.15), lineWidth: 1)
            )
            .opacity(isAvailable ? 1.0 : 0.5)
        }
    }
}


struct TimeSlotSection: View {
    let title: String
    let subtitle: String
    let icon: String
    let slots: [TimeSlot]
    let bookedSlots: [String]
    let selectedSlot: TimeSlot?
    let onSelect: (TimeSlot) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(KHOIColors.mutedText)
                
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(KHOIColors.darkText)
                
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(KHOIColors.mutedText)
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(slots) { slot in
                    // Check BOTH booked status AND availability
                    let isBooked = bookedSlots.contains(slot.time)
                    let isUnavailable = !slot.isAvailable || isBooked
                    let isSelected = selectedSlot?.time == slot.time
                    
                    Button(action: {
                        // Only allow selection if slot is available
                        if !isUnavailable {
                            onSelect(slot)
                        }
                    }) {
                        Text(slot.time)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                isSelected ? KHOIColors.darkText :
                                isUnavailable ? Color.gray.opacity(0.1) : Color.clear
                            )
                            .foregroundColor(
                                isSelected ? .white :
                                isUnavailable ? Color.gray.opacity(0.4) : KHOIColors.darkText
                            )
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        isSelected ? Color.clear :
                                        isUnavailable ? Color.clear : Color.gray.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .disabled(isUnavailable)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct InspoUploadGrid: View {
    @Binding var images: [String]
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var uploadProgress: Int = 0
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    
    var body: some View {
        VStack(spacing: 12) {
            // Upload progress indicator
            if isUploading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Uploading \(uploadProgress) image\(uploadProgress == 1 ? "" : "s")...")
                        .font(.system(size: 12))
                        .foregroundColor(KHOIColors.mutedText)
                }
                .padding(.bottom, 4)
            }
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    if index < images.count {
                        // Show uploaded image
                        ZStack {
                            AsyncImage(url: URL(string: images[index])) { phase in
                                switch phase {
                                case .empty:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .overlay(ProgressView().scaleEffect(0.7))
                                case .success(let img):
                                    img.resizable().scaledToFill()
                                case .failure:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .overlay(
                                            Image(systemName: "exclamationmark.triangle")
                                                .foregroundColor(.orange)
                                        )
                                @unknown default:
                                    Rectangle().fill(Color.gray.opacity(0.2))
                                }
                            }
                            .frame(height: 100)
                            .clipped()
                            .cornerRadius(8)
                            
                            // Remove button
                            Button(action: {
                                withAnimation {
                                    if index < images.count {
                                        images.remove(at: index)
                                    }
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 2)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(6)
                        }
                        .frame(height: 100)
                    } else if index == images.count && !isUploading {
                        // Show single upload button at next available slot
                        PhotosPicker(
                            selection: $selectedItems,
                            maxSelectionCount: 6 - images.count,
                            matching: .images
                        ) {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(KHOIColors.accentBrown)
                                Text("Add")
                                    .font(.system(size: 11))
                                    .foregroundColor(KHOIColors.mutedText)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 100)
                            .background(Color.gray.opacity(0.08))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(KHOIColors.accentBrown.opacity(0.3), lineWidth: 1.5)
                            )
                        }
                        .onChange(of: selectedItems) { newItems in
                            handleImageSelection(newItems)
                        }
                    } else {
                        // Empty placeholder slots
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.05))
                            .frame(height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                    .foregroundColor(Color.gray.opacity(0.2))
                            )
                    }
                }
            }
        }
    }
    
    private func handleImageSelection(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        
        isUploading = true
        uploadProgress = items.count
        
        Task {
            for item in items {
                do {
                    if let data = try await item.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        // Upload to Firebase Storage
                        await uploadImageToStorage(uiImage)
                    }
                } catch {
                    print("Error loading image: \(error)")
                }
            }
            
            await MainActor.run {
                selectedItems = []
                isUploading = false
                uploadProgress = 0
            }
        }
    }
    
    private func uploadImageToStorage(_ image: UIImage) async {
        // Compress and resize image
        let maxSize: CGFloat = 1024
        var processedImage = image
        
        if image.size.width > maxSize || image.size.height > maxSize {
            let scale = min(maxSize / image.size.width, maxSize / image.size.height)
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            if let resized = UIGraphicsGetImageFromCurrentImageContext() {
                processedImage = resized
            }
            UIGraphicsEndImageContext()
        }
        
        guard let imageData = processedImage.jpegData(compressionQuality: 0.7) else {
            print("Failed to compress image")
            return
        }
        
        let imageId = UUID().uuidString
        let path = "inspo_images/\(imageId).jpg"
        let storageRef = Storage.storage().reference().child(path)
        
        do {
            let _ = try await storageRef.putDataAsync(imageData)
            let url = try await storageRef.downloadURL()
            
            await MainActor.run {
                if images.count < 6 {
                    images.append(url.absoluteString)
                }
            }
        } catch {
            print("Error uploading image: \(error)")
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(KHOIColors.mutedText)
            
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(KHOIColors.darkText)
        }
    }
}

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(configuration.isOn ? KHOIColors.accentBrown : KHOIColors.mutedText)
                    .font(.system(size: 20))
                
                configuration.label
            }
        }
    }
}

