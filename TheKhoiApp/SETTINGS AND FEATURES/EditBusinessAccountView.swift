//
//  EditBusinessAccountView.swift
//  TheKhoiApp
//
//  Allows pro users to edit their business information
//

import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseStorage

struct EditBusinessAccountView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSaveSuccess = false
    
    // Editable fields
    @State private var businessName = ""
    @State private var location = ""
    @State private var bio = ""
    @State private var services: [ServiceItem] = []
    @State private var policies = BusinessPolicies()
    @State private var availability = BusinessAvailability()
    @State private var instagramHandle = ""
    
    // UI State
    @State private var selectedSection: EditSection? = nil
    
    enum EditSection: String, CaseIterable {
        case basicInfo = "Basic Info"
        case services = "Services"
        case availability = "Availability"
        case policies = "Policies"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .tint(KHOIColors.accentBrown)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Section cards
                            ForEach(EditSection.allCases, id: \.self) { section in
                                EditSectionCard(
                                    section: section,
                                    isExpanded: selectedSection == section,
                                    onTap: {
                                        withAnimation {
                                            selectedSection = selectedSection == section ? nil : section
                                        }
                                    }
                                ) {
                                    sectionContent(for: section)
                                }
                            }
                            
                            Spacer(minLength: 100)
                        }
                        .padding()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("EDIT BUSINESS")
                        .font(KHOITheme.headline)
                        .tracking(2)
                        .foregroundColor(KHOIColors.mutedText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: saveChanges) {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(KHOIColors.accentBrown)
                    .disabled(isSaving)
                }
            }
            .onAppear {
                loadBusinessData()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Saved!", isPresented: $showSaveSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your business information has been updated.")
            }
        }
    }
    
    // MARK: - Section Content
    
    @ViewBuilder
    private func sectionContent(for section: EditSection) -> some View {
        switch section {
        case .basicInfo:
            basicInfoContent
        case .services:
            servicesContent
        case .availability:
            availabilityContent
        case .policies:
            policiesContent
        }
    }
    
    private var basicInfoContent: some View {
        VStack(spacing: 16) {
            FormTextField(
                title: "Business Name",
                placeholder: "Your business name",
                text: $businessName
            )
            
            FormTextField(
                title: "Location",
                placeholder: "City, State",
                text: $location
            )
            
            FormTextEditor(
                title: "Bio",
                placeholder: "Tell clients about yourself...",
                text: $bio,
                minHeight: 100
            )
            
            FormTextField(
                title: "Instagram Handle",
                placeholder: "@yourusername",
                text: $instagramHandle
            )
        }
    }
    
    private var servicesContent: some View {
        VStack(spacing: 12) {
            ForEach(services) { service in
                EditServiceRow(service: service) {
                    services.removeAll { $0.id == service.id }
                }
            }
            
            Button(action: addNewService) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Service")
                }
                .font(KHOITheme.body)
                .foregroundColor(KHOIColors.accentBrown)
                .frame(maxWidth: .infinity)
                .padding()
                .background(KHOIColors.accentBrown.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private var availabilityContent: some View {
        VStack(spacing: 12) {
            ForEach(0..<7, id: \.self) { index in
                let dayInfo = availability.allDays[index]
                CompactDayRow(
                    dayName: dayInfo.shortName,
                    availability: binding(for: dayInfo.weekday)
                )
            }
        }
    }
    
    private var policiesContent: some View {
        VStack(spacing: 16) {
            FormTextEditor(
                title: "Cancellation Policy",
                placeholder: "Your cancellation policy...",
                text: $policies.cancellationPolicy,
                minHeight: 80
            )
            
            Toggle(isOn: $policies.depositRequired) {
                Text("Require Deposit")
                    .font(KHOITheme.body)
            }
            .tint(KHOIColors.accentBrown)
            
            if policies.depositRequired {
                FormPriceField(
                    title: "Deposit Amount",
                    value: $policies.depositAmount
                )
            }
            
            FormTextEditor(
                title: "Additional Notes",
                placeholder: "Any other policies...",
                text: $policies.additionalNotes,
                minHeight: 60
            )
        }
    }
    
    // MARK: - Helper Views
    
    private func binding(for weekday: Int) -> Binding<DayAvailability> {
        Binding(
            get: { availability.availability(for: weekday) },
            set: { availability.setAvailability(for: weekday, $0) }
        )
    }
    
    private func addNewService() {
        services.append(ServiceItem(
            name: "New Service",
            category: "Makeup",
            duration: 60,
            price: 100
        ))
    }
    
    // MARK: - Data Loading
    
    private func loadBusinessData() {
        guard let userId = authManager.firebaseUID else {
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        
        // Try loading from artists collection first (approved pros)
        db.collection("artists").document(userId).getDocument { snapshot, error in
            if let data = snapshot?.data() {
                // Load from artist document
                self.businessName = data["fullName"] as? String ?? ""
                self.location = data["city"] as? String ?? ""
                self.bio = data["bio"] as? String ?? ""
                self.instagramHandle = data["instagram"] as? String ?? ""
                
                if let servicesData = data["servicesDetailed"] as? [[String: Any]] {
                    self.services = servicesData.map { ServiceItem.fromFirestore($0) }
                }
                
                if let policiesData = data["policies"] as? [String: Any] {
                    self.policies = BusinessPolicies.fromFirestore(policiesData)
                }
                
                if let availabilityData = data["availability"] as? [String: Any] {
                    self.availability = BusinessAvailability.fromFirestore(availabilityData)
                }
                
                self.isLoading = false
            } else {
                // Try pro_applications collection
                self.loadFromApplication(userId: userId)
            }
        }
    }
    
    private func loadFromApplication(userId: String) {
        let db = Firestore.firestore()
        
        db.collection("pro_applications").document(userId).getDocument { snapshot, error in
            if let doc = snapshot, let app = ProApplication.fromFirestore(document: doc) {
                self.businessName = app.businessName
                self.location = app.location
                self.bio = app.bio
                self.instagramHandle = app.instagramHandle
                self.services = app.services
                self.policies = app.policies
                self.availability = app.availability
            }
            self.isLoading = false
        }
    }
    
    // MARK: - Save Changes
    
    private func saveChanges() {
        guard let userId = authManager.firebaseUID else { return }
        
        isSaving = true
        
        let db = Firestore.firestore()
        
        // Update data to save
        let updateData: [String: Any] = [
            "fullName": businessName,
            "city": location,
            "bio": bio,
            "instagram": instagramHandle,
            "servicesDetailed": services.map { $0.toFirestoreData() },
            "policies": policies.toFirestoreData(),
            "availability": availability.toFirestoreData()
        ]
        
        // Update artists collection
        db.collection("artists").document(userId).updateData(updateData) { error in
            if let error = error {
                // If artist doc doesn't exist, try users collection
                db.collection("users").document(userId).updateData([
                    "fullName": self.businessName
                ]) { _ in }
                
                // Also update pro_applications
                db.collection("pro_applications").document(userId).updateData(updateData) { _ in
                    self.isSaving = false
                    self.showSaveSuccess = true
                }
            } else {
                // Also update user's name if changed
                db.collection("users").document(userId).updateData([
                    "fullName": self.businessName
                ]) { _ in }
                
                self.isSaving = false
                self.showSaveSuccess = true
            }
        }
    }
}

// MARK: - Edit Section Card

struct EditSectionCard<Content: View>: View {
    let section: EditBusinessAccountView.EditSection
    let isExpanded: Bool
    let onTap: () -> Void
    @ViewBuilder let content: Content
    
    private var icon: String {
        switch section {
        case .basicInfo: return "person.fill"
        case .services: return "sparkles"
        case .availability: return "clock.fill"
        case .policies: return "doc.text.fill"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: onTap) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(KHOIColors.accentBrown)
                        .frame(width: 24)
                    
                    Text(section.rawValue)
                        .font(KHOITheme.headline)
                        .foregroundColor(KHOIColors.mutedText)
                        .tracking(2)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(KHOIColors.mutedText)
                        .font(.system(size: 14))
                }
                .padding()
            }
            
            // Content
            if isExpanded {
                Divider()
                    .padding(.horizontal)
                
                content
                    .padding()
            }
        }
        .background(KHOIColors.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Edit Service Row

struct EditServiceRow: View {
    let service: ServiceItem
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(service.name)
                    .font(KHOITheme.body)
                    .foregroundColor(KHOIColors.darkText)
                
                Text("\(service.category) • \(service.duration) min • $\(Int(service.price))")
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.mutedText)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.7))
            }
        }
        .padding()
        .background(KHOIColors.chipBackground)
        .cornerRadius(8)
    }
}

// MARK: - Compact Day Row

struct CompactDayRow: View {
    let dayName: String
    @Binding var availability: DayAvailability
    
    var body: some View {
        HStack {
            Text(dayName)
                .font(KHOITheme.body)
                .frame(width: 50, alignment: .leading)
            
            Toggle("", isOn: $availability.isOpen)
                .labelsHidden()
                .tint(KHOIColors.accentBrown)
            
            if availability.isOpen {
                Spacer()
                
                Text("\(formatTime(availability.startHour, availability.startMinute)) - \(formatTime(availability.endHour, availability.endMinute))")
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.mutedText)
            } else {
                Spacer()
                
                Text("Closed")
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.mutedText)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatTime(_ hour: Int, _ minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }
}

