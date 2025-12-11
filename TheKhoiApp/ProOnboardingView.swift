//
//  ProOnboardingView.swift
//  TheKhoiApp
//
//  Multi-step onboarding flow for becoming a verified pro
//

import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseStorage

struct ProOnboardingView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    // Current step (1-6)
    @State private var currentStep = 1
    let totalSteps = 6
    
    // Application data
    @State private var application: ProApplication
    
    // UI State
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccessAlert = false
    
    // Initialize with user data
    init() {
        _application = State(initialValue: ProApplication(
            userId: "",
            userEmail: ""
        ))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress Header
                    progressHeader
                    
                    // Content
                    TabView(selection: $currentStep) {
                        Step1BasicInfoView(application: $application, onNext: nextStep)
                            .tag(1)
                        
                        Step2ServicesView(application: $application, onNext: nextStep, onBack: previousStep)
                            .tag(2)
                        
                        Step3PoliciesView(application: $application, onNext: nextStep, onBack: previousStep)
                            .tag(3)
                        
                        Step4PortfolioView(application: $application, onNext: nextStep, onBack: previousStep)
                            .tag(4)
                        
                        Step5VerificationView(application: $application, onNext: nextStep, onBack: previousStep)
                            .tag(5)
                        
                        Step6ReviewView(application: $application, onSubmit: submitApplication, onBack: previousStep, isLoading: isLoading)
                            .tag(6)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: currentStep)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(KHOIColors.brandRed)
                    }
                }
            }
            .onAppear {
                // Set user info
                if let uid = authManager.firebaseUID,
                   let email = authManager.currentUser?.email {
                    application.userId = uid
                    application.userEmail = email
                    
                    // Pre-fill business name with user's name
                    if let fullName = authManager.currentUser?.fullName {
                        application.businessName = fullName
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Something went wrong")
            }
            .alert("Application Submitted!", isPresented: $showSuccessAlert) {
                Button("Done") { dismiss() }
            } message: {
                Text("We'll review your application and get back to you within 24-48 hours.")
            }
        }
    }
    
    // MARK: - Progress Header
    private var progressHeader: some View {
        VStack(spacing: 16) {
            // Step indicator
            HStack(spacing: 8) {
                ForEach(1...totalSteps, id: \.self) { step in
                    Capsule()
                        .fill(step <= currentStep ? KHOIColors.accentBrown : KHOIColors.chipBackground)
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 24)
            
            // Step title
            Text(stepTitle)
                .font(KHOITheme.headline)
                .foregroundColor(KHOIColors.darkText)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    private var stepTitle: String {
        switch currentStep {
        case 1: return "Basic Information"
        case 2: return "Your Services"
        case 3: return "Business Policies"
        case 4: return "Portfolio"
        case 5: return "Verification"
        case 6: return "Review & Submit"
        default: return ""
        }
    }
    
    // MARK: - Navigation
    private func nextStep() {
        withAnimation {
            if currentStep < totalSteps {
                currentStep += 1
            }
        }
    }
    
    private func previousStep() {
        withAnimation {
            if currentStep > 1 {
                currentStep -= 1
            }
        }
    }
    
    // MARK: - Submit Application
    private func submitApplication() {
        isLoading = true
        
        let db = Firestore.firestore()
        
        // Update application status
        application.status = .pending
        application.submittedAt = Date()
        
        // Save to Firestore
        db.collection("pro_applications").document(application.userId).setData(application.toFirestoreData()) { error in
            isLoading = false
            
            if let error = error {
                errorMessage = error.localizedDescription
                showError = true
            } else {
                // Update user's pending status
                authManager.setPendingProStatus(true)
                
                // Send notification about application submission
                NotificationService.shared.sendProApplicationStatusNotification(
                    status: "pending",
                    businessName: application.businessName
                )
                
                // Start listening for status changes
                NotificationService.shared.listenForProApplicationStatus(userId: application.userId)
                
                showSuccessAlert = true
            }
        }
    }
}

// MARK: - Step 1: Basic Info
struct Step1BasicInfoView: View {
    @Binding var application: ProApplication
    let onNext: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Let's start with the basics")
                    .font(KHOITheme.body)
                    .foregroundColor(KHOIColors.mutedText)
                    .padding(.horizontal)
                
                VStack(spacing: 20) {
                    // Business Name
                    FormTextField(
                        title: "Business Name",
                        placeholder: "e.g., Glam by Jessica",
                        text: $application.businessName
                    )
                    
                    // Location
                    FormTextField(
                        title: "Location",
                        placeholder: "e.g., Los Angeles, CA",
                        text: $application.location
                    )
                    
                    // Bio
                    FormTextEditor(
                        title: "About Your Business",
                        placeholder: "Tell clients what makes you unique...",
                        text: $application.bio,
                        minHeight: 120
                    )
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
            .padding(.top, 16)
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingButton(
                title: "Continue",
                isEnabled: application.isStep1Valid,
                action: onNext
            )
        }
    }
}

// MARK: - Step 2: Services
struct Step2ServicesView: View {
    @Binding var application: ProApplication
    let onNext: () -> Void
    let onBack: () -> Void
    
    @State private var showAddService = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Add the services you offer")
                    .font(KHOITheme.body)
                    .foregroundColor(KHOIColors.mutedText)
                    .padding(.horizontal)
                
                // Services List
                if application.services.isEmpty {
                    emptyServicesView
                } else {
                    VStack(spacing: 12) {
                        ForEach(application.services) { service in
                            ServiceCard(service: service) {
                                // Delete action
                                application.services.removeAll { $0.id == service.id }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Add Service Button
                Button(action: { showAddService = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Service")
                    }
                    .font(KHOITheme.bodyBold)
                    .foregroundColor(KHOIColors.accentBrown)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(KHOIColors.accentBrown.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
            .padding(.top, 16)
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingButtonPair(
                backAction: onBack,
                nextTitle: "Continue",
                isNextEnabled: application.isStep2Valid,
                nextAction: onNext
            )
        }
        .sheet(isPresented: $showAddService) {
            AddServiceSheet(services: $application.services)
        }
    }
    
    private var emptyServicesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(KHOIColors.mutedText.opacity(0.5))
            
            Text("No services added yet")
                .font(KHOITheme.body)
                .foregroundColor(KHOIColors.mutedText)
            
            Text("Add at least one service to continue")
                .font(KHOITheme.caption)
                .foregroundColor(KHOIColors.mutedText.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Service Card
struct ServiceCard: View {
    let service: ServiceItem
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Color Bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: ServiceCategories.color(for: service.category)))
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(service.name)
                    .font(KHOITheme.bodyBold)
                    .foregroundColor(KHOIColors.darkText)
                
                Text("\(service.category) • \(service.duration) min • $\(Int(service.price))")
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.mutedText)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.7))
                    .padding(8)
            }
        }
        .padding()
        .background(KHOIColors.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Add Service Sheet
struct AddServiceSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var services: [ServiceItem]
    
    @State private var service = ServiceItem()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Service Name
                    FormTextField(
                        title: "Service Name",
                        placeholder: "e.g., Bridal Glam Makeup",
                        text: $service.name
                    )
                    
                    // Category
                    FormPicker(
                        title: "Category",
                        selection: $service.category,
                        options: ServiceCategories.all
                    )
                    
                    // Description
                    FormTextEditor(
                        title: "Description",
                        placeholder: "What's included in this service?",
                        text: $service.description,
                        minHeight: 80
                    )
                    
                    // Duration
                    FormNumberField(
                        title: "Duration (minutes)",
                        value: $service.duration,
                        range: 15...480
                    )
                    
                    // Price
                    FormPriceField(
                        title: "Price",
                        value: $service.price
                    )
                }
                .padding()
            }
            .background(KHOIColors.background)
            .navigationTitle("Add Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(KHOIColors.mutedText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        services.append(service)
                        dismiss()
                    }
                    .font(.body.bold())
                    .foregroundColor(service.isValid ? KHOIColors.accentBrown : KHOIColors.mutedText)
                    .disabled(!service.isValid)
                }
            }
        }
    }
}

// MARK: - Step 3: Policies
struct Step3PoliciesView: View {
    @Binding var application: ProApplication
    let onNext: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Set your business policies")
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.mutedText)
                    
                    Text("Optional but recommended")
                        .font(KHOITheme.caption)
                        .foregroundColor(KHOIColors.mutedText.opacity(0.7))
                }
                .padding(.horizontal)
                
                VStack(spacing: 20) {
                    // Cancellation Policy
                    FormTextEditor(
                        title: "Cancellation Policy",
                        placeholder: "e.g., 24 hour notice required for full refund",
                        text: $application.policies.cancellationPolicy,
                        minHeight: 80
                    )
                    
                    // Deposit Toggle
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $application.policies.depositRequired) {
                            Text("Require Deposit")
                                .font(KHOITheme.bodyBold)
                                .foregroundColor(KHOIColors.darkText)
                        }
                        .tint(KHOIColors.accentBrown)
                        
                        if application.policies.depositRequired {
                            FormPriceField(
                                title: "Deposit Amount",
                                value: $application.policies.depositAmount
                            )
                        }
                    }
                    .padding()
                    .background(KHOIColors.cardBackground)
                    .cornerRadius(12)
                    
                    // Advance Booking
                    FormNumberField(
                        title: "Advance Booking (days)",
                        value: $application.policies.advanceBookingDays,
                        range: 1...90
                    )
                    
                    // Late Arrival Policy
                    FormTextEditor(
                        title: "Late Arrival Policy",
                        placeholder: "e.g., 15 min grace period, appointment shortened after",
                        text: $application.policies.lateArrivalPolicy,
                        minHeight: 60
                    )
                    
                    // Additional Notes
                    FormTextEditor(
                        title: "Additional Notes",
                        placeholder: "e.g., Please arrive with clean skin",
                        text: $application.policies.additionalNotes,
                        minHeight: 60
                    )
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
            .padding(.top, 16)
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingButtonPair(
                backAction: onBack,
                nextTitle: "Continue",
                isNextEnabled: true,
                nextAction: onNext
            )
        }
    }
}

// MARK: - Step 4: Portfolio
struct Step4PortfolioView: View {
    @Binding var application: ProApplication
    let onNext: () -> Void
    let onBack: () -> Void
    
    @State private var selectedCategory: String = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Show off your best work")
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.mutedText)
                    
                    Text("Upload at least 2 photos per service category")
                        .font(KHOITheme.caption)
                        .foregroundColor(KHOIColors.mutedText.opacity(0.7))
                }
                .padding(.horizontal)
                
                // Category Sections
                ForEach(application.serviceCategories, id: \.self) { category in
                    portfolioCategorySection(category: category)
                }
                
                if application.serviceCategories.isEmpty {
                    Text("Add services first to upload portfolio images")
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.mutedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                }
                
                Spacer(minLength: 100)
            }
            .padding(.top, 16)
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingButtonPair(
                backAction: onBack,
                nextTitle: "Continue",
                isNextEnabled: application.isStep4Valid,
                nextAction: onNext
            )
        }
        .overlay {
            if isUploading {
                uploadingOverlay
            }
        }
    }
    
    private func portfolioCategorySection(category: String) -> some View {
        let categoryImages = application.portfolioImages.filter { $0.serviceCategory == category }
        let isValid = categoryImages.count >= 2
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(category)
                    .font(KHOITheme.bodyBold)
                    .foregroundColor(KHOIColors.darkText)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .foregroundColor(isValid ? .green : .orange)
                    Text("\(categoryImages.count)/2 min")
                        .font(KHOITheme.caption)
                        .foregroundColor(KHOIColors.mutedText)
                }
            }
            
            // Image Grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                ForEach(categoryImages) { image in
                    portfolioImageTile(image: image)
                }
                
                // Add Photo Button
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    VStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.title2)
                        Text("Add")
                            .font(KHOITheme.caption)
                    }
                    .foregroundColor(KHOIColors.mutedText)
                    .frame(width: 100, height: 100)
                    .background(KHOIColors.chipBackground)
                    .cornerRadius(12)
                }
                .onChange(of: selectedPhotos) { _, newValue in
                    if !newValue.isEmpty {
                        selectedCategory = category
                        uploadPhotos(items: newValue, category: category)
                        selectedPhotos = []
                    }
                }
            }
        }
        .padding()
        .background(KHOIColors.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func portfolioImageTile(image: PortfolioImage) -> some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: URL(string: image.url)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 100, height: 100)
                case .success(let img):
                    img
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipped()
                        .cornerRadius(8)
                case .failure:
                    Image(systemName: "photo")
                        .frame(width: 100, height: 100)
                        .background(KHOIColors.chipBackground)
                        .cornerRadius(8)
                @unknown default:
                    EmptyView()
                }
            }
            
            // Delete button
            Button(action: {
                application.portfolioImages.removeAll { $0.id == image.id }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .padding(4)
        }
    }
    
    private var uploadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Uploading photos...")
                    .font(KHOITheme.body)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(KHOIColors.darkText)
            .cornerRadius(16)
        }
    }
    
    private func uploadPhotos(items: [PhotosPickerItem], category: String) {
        guard let userId = application.userId.isEmpty ? nil : application.userId else { return }
        
        isUploading = true
        let storage = Storage.storage()
        let group = DispatchGroup()
        
        for item in items {
            group.enter()
            
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let imageId = UUID().uuidString
                    let ref = storage.reference().child("portfolio_images/\(userId)/\(imageId).jpg")
                    
                    ref.putData(data) { _, error in
                        if error == nil {
                            ref.downloadURL { url, _ in
                                if let url = url {
                                    DispatchQueue.main.async {
                                        let portfolioImage = PortfolioImage(
                                            url: url.absoluteString,
                                            serviceCategory: category
                                        )
                                        application.portfolioImages.append(portfolioImage)
                                    }
                                }
                                group.leave()
                            }
                        } else {
                            group.leave()
                        }
                    }
                } else {
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            isUploading = false
        }
    }
}

// MARK: - Step 5: Verification
struct Step5VerificationView: View {
    @Binding var application: ProApplication
    let onNext: () -> Void
    let onBack: () -> Void
    
    @State private var selectedProofType: BusinessProofType = .instagram
    @State private var proofPhoto: PhotosPickerItem?
    @State private var isUploading = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Verify your business")
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.mutedText)
                    
                    Text("This helps us ensure quality for our community")
                        .font(KHOITheme.caption)
                        .foregroundColor(KHOIColors.mutedText.opacity(0.7))
                }
                .padding(.horizontal)
                
                // Instagram Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "camera")
                            .foregroundColor(Color(hex: "E1306C"))
                        Text("Instagram")
                            .font(KHOITheme.bodyBold)
                    }
                    
                    FormTextField(
                        title: "",
                        placeholder: "@yourusername",
                        text: $application.instagramHandle
                    )
                    
                    Text("We'll verify your account has beauty-related content")
                        .font(KHOITheme.caption)
                        .foregroundColor(KHOIColors.mutedText)
                }
                .padding()
                .background(KHOIColors.cardBackground)
                .cornerRadius(12)
                .padding(.horizontal)
                
                // OR Divider
                HStack {
                    Rectangle()
                        .fill(KHOIColors.divider)
                        .frame(height: 1)
                    Text("OR")
                        .font(KHOITheme.caption)
                        .foregroundColor(KHOIColors.mutedText)
                    Rectangle()
                        .fill(KHOIColors.divider)
                        .frame(height: 1)
                }
                .padding(.horizontal, 32)
                
                // Business Proof Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Upload Business Proof")
                        .font(KHOITheme.bodyBold)
                        .foregroundColor(KHOIColors.darkText)
                    
                    // Proof Type Selection
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(BusinessProofType.allCases, id: \.self) { type in
                                if type != .instagram {
                                    proofTypeButton(type: type)
                                }
                            }
                        }
                    }
                    
                    // Upload Area
                    if application.businessProofURL != nil {
                        // Show uploaded proof
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Proof uploaded")
                                .font(KHOITheme.body)
                            Spacer()
                            Button("Remove") {
                                application.businessProofURL = nil
                                application.businessProofType = nil
                            }
                            .font(KHOITheme.caption)
                            .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        PhotosPicker(selection: $proofPhoto, matching: .images) {
                            VStack(spacing: 12) {
                                Image(systemName: "arrow.up.doc")
                                    .font(.title)
                                Text("Tap to upload \(selectedProofType.displayName)")
                                    .font(KHOITheme.body)
                            }
                            .foregroundColor(KHOIColors.mutedText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                                    .foregroundColor(KHOIColors.divider)
                            )
                        }
                        .onChange(of: proofPhoto) { _, newValue in
                            if let item = newValue {
                                uploadProof(item: item)
                            }
                        }
                    }
                }
                .padding()
                .background(KHOIColors.cardBackground)
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
            .padding(.top, 16)
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingButtonPair(
                backAction: onBack,
                nextTitle: "Continue",
                isNextEnabled: application.isStep5Valid,
                nextAction: onNext
            )
        }
        .overlay {
            if isUploading {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView("Uploading...")
                        .padding()
                        .background(KHOIColors.cardBackground)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private func proofTypeButton(type: BusinessProofType) -> some View {
        Button(action: { selectedProofType = type }) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title3)
                Text(type.displayName)
                    .font(KHOITheme.caption)
            }
            .foregroundColor(selectedProofType == type ? .white : KHOIColors.darkText)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(selectedProofType == type ? KHOIColors.darkText : KHOIColors.chipBackground)
            .cornerRadius(8)
        }
    }
    
    private func uploadProof(item: PhotosPickerItem) {
        guard !application.userId.isEmpty else { return }
        
        isUploading = true
        
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let storage = Storage.storage()
                let docId = UUID().uuidString
                let ref = storage.reference().child("business_proof/\(application.userId)/\(docId).jpg")
                
                ref.putData(data) { _, error in
                    if error == nil {
                        ref.downloadURL { url, _ in
                            DispatchQueue.main.async {
                                if let url = url {
                                    application.businessProofURL = url.absoluteString
                                    application.businessProofType = selectedProofType
                                }
                                isUploading = false
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            isUploading = false
                        }
                    }
                }
            } else {
                isUploading = false
            }
        }
    }
}

// MARK: - Step 6: Review
struct Step6ReviewView: View {
    @Binding var application: ProApplication
    let onSubmit: () -> Void
    let onBack: () -> Void
    let isLoading: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Review your application")
                    .font(KHOITheme.body)
                    .foregroundColor(KHOIColors.mutedText)
                    .padding(.horizontal)
                
                // Basic Info Card
                reviewCard(title: "Basic Info", icon: "person.fill") {
                    reviewRow(label: "Business Name", value: application.businessName)
                    reviewRow(label: "Location", value: application.location)
                    reviewRow(label: "Bio", value: application.bio)
                }
                
                // Services Card
                reviewCard(title: "Services", icon: "sparkles") {
                    ForEach(application.services) { service in
                        HStack {
                            Text(service.name)
                                .font(KHOITheme.body)
                            Spacer()
                            Text("$\(Int(service.price))")
                                .font(KHOITheme.caption)
                                .foregroundColor(KHOIColors.mutedText)
                        }
                        if service.id != application.services.last?.id {
                            Divider()
                        }
                    }
                }
                
                // Policies Card
                if !application.policies.cancellationPolicy.isEmpty || application.policies.depositRequired {
                    reviewCard(title: "Policies", icon: "doc.text") {
                        if !application.policies.cancellationPolicy.isEmpty {
                            reviewRow(label: "Cancellation", value: application.policies.cancellationPolicy)
                        }
                        if application.policies.depositRequired {
                            reviewRow(label: "Deposit", value: "$\(Int(application.policies.depositAmount))")
                        }
                    }
                }
                
                // Portfolio Card
                reviewCard(title: "Portfolio", icon: "photo.on.rectangle") {
                    Text("\(application.portfolioImages.count) photos uploaded")
                        .font(KHOITheme.body)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(application.portfolioImages.prefix(6)) { image in
                                AsyncImage(url: URL(string: image.url)) { img in
                                    img
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 60)
                                        .clipped()
                                        .cornerRadius(8)
                                } placeholder: {
                                    Rectangle()
                                        .fill(KHOIColors.chipBackground)
                                        .frame(width: 60, height: 60)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                
                // Verification Card
                reviewCard(title: "Verification", icon: "checkmark.seal") {
                    if !application.instagramHandle.isEmpty {
                        reviewRow(label: "Instagram", value: "@\(application.instagramHandle)")
                    }
                    if application.businessProofURL != nil {
                        reviewRow(label: "Business Proof", value: application.businessProofType?.displayName ?? "Uploaded")
                    }
                }
                
                // Disclaimer
                Text("By submitting, you confirm that all information is accurate and you agree to our Terms of Service.")
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.mutedText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Spacer(minLength: 120)
            }
            .padding(.top, 16)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button(action: onSubmit) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Submit Application")
                        }
                    }
                    .font(KHOITheme.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(application.isReadyToSubmit ? KHOIColors.accentBrown : KHOIColors.mutedText)
                    .cornerRadius(16)
                }
                .disabled(!application.isReadyToSubmit || isLoading)
                
                Button(action: onBack) {
                    Text("Back")
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.mutedText)
                }
            }
            .padding()
            .background(KHOIColors.background)
        }
    }
    
    private func reviewCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(KHOIColors.accentBrown)
                Text(title)
                    .font(KHOITheme.bodyBold)
            }
            
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KHOIColors.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func reviewRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(KHOITheme.caption)
                .foregroundColor(KHOIColors.mutedText)
            Text(value)
                .font(KHOITheme.body)
                .foregroundColor(KHOIColors.darkText)
        }
    }
}

// MARK: - Reusable Form Components

struct FormTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.mutedText)
            }
            
            TextField(placeholder, text: $text)
                .font(KHOITheme.body)
                .padding()
                .background(KHOIColors.cardBackground)
                .cornerRadius(12)
        }
    }
}

struct FormTextEditor: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 100
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.mutedText)
            }
            
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.mutedText.opacity(0.5))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                
                TextEditor(text: $text)
                    .font(KHOITheme.body)
                    .frame(minHeight: minHeight)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .background(KHOIColors.cardBackground)
            .cornerRadius(12)
        }
    }
}

struct FormPicker: View {
    let title: String
    @Binding var selection: String
    let options: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(KHOITheme.caption)
                .foregroundColor(KHOIColors.mutedText)
            
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        selection = option
                    }
                }
            } label: {
                HStack {
                    Text(selection)
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.darkText)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(KHOIColors.mutedText)
                }
                .padding()
                .background(KHOIColors.cardBackground)
                .cornerRadius(12)
            }
        }
    }
}

struct FormNumberField: View {
    let title: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...999
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(KHOITheme.caption)
                .foregroundColor(KHOIColors.mutedText)
            
            HStack {
                Button(action: { if value > range.lowerBound { value -= 1 } }) {
                    Image(systemName: "minus")
                        .padding(12)
                        .background(KHOIColors.chipBackground)
                        .cornerRadius(8)
                }
                
                Text("\(value)")
                    .font(KHOITheme.headline)
                    .frame(minWidth: 60)
                
                Button(action: { if value < range.upperBound { value += 1 } }) {
                    Image(systemName: "plus")
                        .padding(12)
                        .background(KHOIColors.chipBackground)
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .background(KHOIColors.cardBackground)
            .cornerRadius(12)
        }
    }
}

struct FormPriceField: View {
    let title: String
    @Binding var value: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.mutedText)
            }
            
            HStack {
                Text("$")
                    .font(KHOITheme.headline)
                    .foregroundColor(KHOIColors.mutedText)
                
                TextField("0", value: $value, format: .number)
                    .font(KHOITheme.headline)
                    .keyboardType(.decimalPad)
            }
            .padding()
            .background(KHOIColors.cardBackground)
            .cornerRadius(12)
        }
    }
}

// MARK: - Onboarding Buttons

struct OnboardingButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(KHOITheme.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isEnabled ? KHOIColors.darkText : KHOIColors.mutedText)
                .cornerRadius(16)
        }
        .disabled(!isEnabled)
        .padding()
        .background(KHOIColors.background)
    }
}

struct OnboardingButtonPair: View {
    let backAction: () -> Void
    let nextTitle: String
    var isNextEnabled: Bool = true
    let nextAction: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: backAction) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(KHOIColors.darkText)
                    .padding()
                    .background(KHOIColors.cardBackground)
                    .cornerRadius(12)
            }
            
            Button(action: nextAction) {
                Text(nextTitle)
                    .font(KHOITheme.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isNextEnabled ? KHOIColors.darkText : KHOIColors.mutedText)
                    .cornerRadius(16)
            }
            .disabled(!isNextEnabled)
        }
        .padding()
        .background(KHOIColors.background)
    }
}
