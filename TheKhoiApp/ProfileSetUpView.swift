//
//  ProfileSetupView.swift
//  TheKhoiApp
//
//

import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var currentStep: OnboardingStep = .welcome
    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    
    // Photo states
    @State private var selectedProfileItem: PhotosPickerItem? = nil
    @State private var selectedCoverItem: PhotosPickerItem? = nil
    @State private var profileImage: UIImage? = nil
    @State private var coverImage: UIImage? = nil
    @State private var isLoadingImage = false
    
    // Cropper states
    @State private var showProfileCropper = false
    @State private var showCoverCropper = false
    @State private var tempProfileImage: UIImage? = nil
    @State private var tempCoverImage: UIImage? = nil
    
    @State private var errorMessage: String?
    @State private var isSubmitting: Bool = false
    @State private var showLogoutConfirmation: Bool = false
    
    enum OnboardingStep {
        case welcome
        case accountInfo
        case profile
        case photos
        case security
    }
    
    var body: some View {
        ZStack {
            KHOIColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar with back button
                topBar
                
                // Progress indicator
                progressBar
                
                // Content based on current step
                ScrollView {
                    VStack(spacing: 24) {
                        switch currentStep {
                        case .welcome:
                            welcomeStep
                        case .accountInfo:
                            accountInfoStep
                        case .profile:
                            profileStep
                        case .photos:
                            photosStep
                        case .security:
                            securityStep
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 100)
                }
                
                Spacer()
                
                // Bottom action button
                bottomButton
            }
            
            // Loading overlay for images
            if isLoadingImage {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                        Text("Loading image...")
                            .font(KHOITheme.body)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Cancel Setup?", isPresented: $showLogoutConfirmation) {
            Button("Stay", role: .cancel) { }
            Button("Leave", role: .destructive) {
                authManager.logOut()
            }
        } message: {
            Text("Your progress won't be saved. You'll need to sign in again.")
        }
        .onAppear {
            fullName = authManager.authenticatedName ?? ""
            email = authManager.authenticatedEmail ?? ""
        }
        .onChange(of: selectedProfileItem) { _, newItem in
            Task {
                if let newItem = newItem {
                    isLoadingImage = true
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let originalImage = UIImage(data: data) {
                        let resized = resizeImage(originalImage, maxDimension: 1500)
                        await MainActor.run {
                            tempProfileImage = resized
                            isLoadingImage = false
                            showProfileCropper = true
                        }
                    } else {
                        await MainActor.run {
                            isLoadingImage = false
                        }
                    }
                }
            }
        }
        .onChange(of: selectedCoverItem) { _, newItem in
            Task {
                if let newItem = newItem {
                    isLoadingImage = true
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let originalImage = UIImage(data: data) {
                        let resized = resizeImage(originalImage, maxDimension: 1500)
                        await MainActor.run {
                            tempCoverImage = resized
                            isLoadingImage = false
                            showCoverCropper = true
                        }
                    } else {
                        await MainActor.run {
                            isLoadingImage = false
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showProfileCropper) {
            if let image = tempProfileImage {
                SetupImageCropperView(
                    image: image,
                    aspectRatio: 1.0,
                    onCrop: { croppedImage in
                        profileImage = croppedImage
                        showProfileCropper = false
                        tempProfileImage = nil
                        selectedProfileItem = nil
                    },
                    onCancel: {
                        showProfileCropper = false
                        tempProfileImage = nil
                        selectedProfileItem = nil
                    }
                )
                .ignoresSafeArea()
            }
        }
        .fullScreenCover(isPresented: $showCoverCropper) {
            if let image = tempCoverImage {
                SetupImageCropperView(
                    image: image,
                    aspectRatio: 3.0,
                    onCrop: { croppedImage in
                        coverImage = croppedImage
                        showCoverCropper = false
                        tempCoverImage = nil
                        selectedCoverItem = nil
                    },
                    onCancel: {
                        showCoverCropper = false
                        tempCoverImage = nil
                        selectedCoverItem = nil
                    }
                )
                .ignoresSafeArea()
            }
        }
    }
    
    // MARK: - Helper: Resize Image
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSize = max(size.width, size.height)
        
        if maxSize <= maxDimension {
            return image
        }
        
        let scale = maxDimension / maxSize
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            if currentStep != .welcome {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(KHOIColors.darkText)
                        .padding(12)
                        .background(KHOIColors.cardBackground)
                        .clipShape(Circle())
                }
            } else {
                Button(action: { showLogoutConfirmation = true }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(KHOIColors.darkText)
                        .padding(12)
                        .background(KHOIColors.cardBackground)
                        .clipShape(Circle())
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Progress Bar
    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<4) { index in
                Rectangle()
                    .fill(index < stepNumber ? KHOIColors.accentBrown : KHOIColors.chipBackground)
                    .frame(height: 4)
                    .cornerRadius(2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    private var stepNumber: Int {
        switch currentStep {
        case .welcome: return 0
        case .accountInfo: return 1
        case .profile: return 2
        case .photos: return 3
        case .security: return 4
        }
    }
    
    // MARK: - Welcome Step
    private var welcomeStep: some View {
        VStack(spacing: 32) {
            Spacer().frame(height: 40)
            
            // Logo/Branding
            VStack(spacing: 16) {
                Image("khoi icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)

                
                Text("Welcome to KHOI")
                    .font(KHOITheme.title)
                    .foregroundColor(KHOIColors.darkText)
                    .tracking(2)
                
                Text("Let's set up your profile.")
                    .font(KHOITheme.body)
                    .foregroundColor(KHOIColors.mutedText)
            }
            
            Spacer().frame(height: 20)
            
            // Features list
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(icon: "sparkles", title: "Discover Beauty Near You")
                FeatureRow(icon: "calendar", title: "Book Appointments Instantly")
                FeatureRow(icon: "bookmark", title: "Save Your Favorite Looks")
            }
            .padding(.horizontal, 8)
            
            Spacer()
        }
    }
    
    // MARK: - Account Info Step
    private var accountInfoStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Account")
                    .font(KHOITheme.title)
                    .foregroundColor(KHOIColors.darkText)
                
                Text("This information comes from your sign-in provider. You can update your name if needed.")
                    .font(KHOITheme.callout)
                    .foregroundColor(KHOIColors.mutedText)
            }
            
            VStack(spacing: 16) {
                StyledTextField(
                    label: "Full Name",
                    text: $fullName,
                    placeholder: "Enter your name",
                    icon: "person"
                )
                
                StyledTextField(
                    label: "Email",
                    text: $email,
                    placeholder: "your@email.com",
                    icon: "envelope",
                    disabled: true
                )
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.danger)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Profile Step
    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Create Your Profile")
                    .font(KHOITheme.title)
                    .foregroundColor(KHOIColors.darkText)
                
                Text("Choose a unique username and tell others about yourself.")
                    .font(KHOITheme.callout)
                    .foregroundColor(KHOIColors.mutedText)
            }
            
            VStack(spacing: 16) {
                StyledTextField(
                    label: "Username",
                    text: $username,
                    placeholder: "username",
                    icon: "at"
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 16))
                            .foregroundColor(KHOIColors.mutedText)
                        Text("Bio")
                            .font(KHOITheme.callout)
                            .foregroundColor(KHOIColors.mutedText)
                    }
                    
                    ZStack(alignment: .topLeading) {
                        if bio.isEmpty {
                            Text("Tell us about yourself...")
                                .font(KHOITheme.body)
                                .foregroundColor(KHOIColors.mutedText.opacity(0.6))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                        }
                        
                        TextEditor(text: $bio)
                            .font(KHOITheme.body)
                            .foregroundColor(KHOIColors.darkText)
                            .frame(minHeight: 100)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .scrollContentBackground(.hidden)
                    }
                    .background(KHOIColors.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(KHOIColors.divider, lineWidth: 1)
                    )
                }
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.danger)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Photos Step
    private var photosStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Your Photos")
                    .font(KHOITheme.title)
                    .foregroundColor(KHOIColors.darkText)
                
                Text("Add a profile picture and cover photo. You can skip this and add them later.")
                    .font(KHOITheme.callout)
                    .foregroundColor(KHOIColors.mutedText)
            }
            
            // Preview card showing how profile will look
            VStack(spacing: 0) {
                // Cover image
                ZStack(alignment: .bottomTrailing) {
                    if let coverImage = coverImage {
                        Image(uiImage: coverImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 120)
                            .clipped()
                    } else {
                        LinearGradient(
                            colors: [Color(hex: "8B4D5C"), Color(hex: "C4A07C")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 120)
                    }
                    
                    // Edit cover button
                    PhotosPicker(selection: $selectedCoverItem, matching: .images) {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12))
                            Text("Edit")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(16)
                    }
                    .padding(12)
                }
                .cornerRadius(16, corners: [.topLeft, .topRight])
                
                // Profile picture overlapping
                HStack {
                    ZStack(alignment: .bottomTrailing) {
                        if let profileImage = profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(KHOIColors.background, lineWidth: 4)
                                )
                        } else {
                            Circle()
                                .fill(KHOIColors.chipBackground)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(KHOIColors.mutedText)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(KHOIColors.background, lineWidth: 4)
                                )
                        }
                        
                        // Edit profile picture button
                        PhotosPicker(selection: $selectedProfileItem, matching: .images) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(KHOIColors.accentBrown)
                                .clipShape(Circle())
                        }
                        .offset(x: 4, y: 4)
                    }
                    .offset(y: -40)
                    .padding(.leading, 16)
                    
                    Spacer()
                }
                .padding(.bottom, -32)
                
                // Name preview
                VStack(alignment: .leading, spacing: 4) {
                    Text(fullName.isEmpty ? "Your Name" : fullName)
                        .font(KHOITheme.headline)
                        .foregroundColor(KHOIColors.darkText)
                    
                    Text("@\(username.isEmpty ? "username" : username)")
                        .font(KHOITheme.callout)
                        .foregroundColor(KHOIColors.mutedText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 48)
                .padding(.bottom, 16)
            }
            .background(KHOIColors.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            
            // Helper text
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14))
                    .foregroundColor(KHOIColors.accentBrown)
                
                Text("Tip: Profiles with photos get more engagement!")
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.mutedText)
            }
            .padding(.top, 8)
            
            Spacer()
        }
    }
    
    // MARK: - Security Step
    private var securityStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Secure Your Account")
                    .font(KHOITheme.title)
                    .foregroundColor(KHOIColors.darkText)
                
                Text("Create a strong password to protect your account.")
                    .font(KHOITheme.callout)
                    .foregroundColor(KHOIColors.mutedText)
            }
            
            VStack(spacing: 16) {
                StyledSecureField(
                    label: "Password",
                    text: $password,
                    placeholder: "Create a password",
                    icon: "lock"
                )
                
                // Password strength indicator
                if !password.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            ForEach(0..<4) { index in
                                Rectangle()
                                    .fill(index < passwordStrength ? strengthColor : KHOIColors.chipBackground)
                                    .frame(height: 4)
                                    .cornerRadius(2)
                            }
                        }
                        
                        Text("Password strength: \(strengthText)")
                            .font(KHOITheme.caption)
                            .foregroundColor(strengthColor)
                    }
                }
                
                StyledSecureField(
                    label: "Confirm Password",
                    text: $confirmPassword,
                    placeholder: "Confirm your password",
                    icon: "lock.fill"
                )
                
                // Password requirements
                VStack(alignment: .leading, spacing: 8) {
                    PasswordRequirement(text: "At least 6 characters", met: password.count >= 6)
                    PasswordRequirement(text: "Passwords match", met: !confirmPassword.isEmpty && password == confirmPassword)
                }
                .padding(.top, 8)
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.danger)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Bottom Button
    private var bottomButton: some View {
        VStack(spacing: 0) {
            Divider()
            
            Button(action: handleNext) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    }
                    
                    Text(buttonTitle)
                        .font(KHOITheme.bodyBold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isButtonEnabled ? KHOIColors.accentBrown : KHOIColors.mutedText)
                .cornerRadius(12)
            }
            .disabled(!isButtonEnabled || isSubmitting)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(KHOIColors.background)
    }
    
    // MARK: - Helpers
    
    private var buttonTitle: String {
        switch currentStep {
        case .welcome: return "Get Started"
        case .accountInfo: return "Continue"
        case .profile: return "Continue"
        case .photos: return profileImage == nil && coverImage == nil ? "Skip for Now" : "Continue"
        case .security: return isSubmitting ? "Creating Account..." : "Complete Setup"
        }
    }
    
    private var isButtonEnabled: Bool {
        switch currentStep {
        case .welcome: return true
        case .accountInfo: return !fullName.trimmingCharacters(in: .whitespaces).isEmpty
        case .profile: return !username.trimmingCharacters(in: .whitespaces).isEmpty
        case .photos: return true // Always enabled, can skip
        case .security: return password.count >= 6 && password == confirmPassword
        }
    }
    
    private var passwordStrength: Int {
        let length = password.count
        if length >= 12 { return 4 }
        if length >= 10 { return 3 }
        if length >= 8 { return 2 }
        if length >= 6 { return 1 }
        return 0
    }
    
    private var strengthColor: Color {
        switch passwordStrength {
        case 4: return .green
        case 3: return Color(hex: "8B7355")
        case 2: return .orange
        default: return .red
        }
    }
    
    private var strengthText: String {
        switch passwordStrength {
        case 4: return "Very Strong"
        case 3: return "Strong"
        case 2: return "Fair"
        default: return "Weak"
        }
    }
    
    private func handleNext() {
        errorMessage = nil
        
        switch currentStep {
        case .welcome:
            withAnimation {
                currentStep = .accountInfo
            }
        case .accountInfo:
            if fullName.trimmingCharacters(in: .whitespaces).isEmpty {
                errorMessage = "Please enter your name"
                return
            }
            withAnimation {
                currentStep = .profile
            }
        case .profile:
            if username.trimmingCharacters(in: .whitespaces).isEmpty {
                errorMessage = "Please choose a username"
                return
            }
            withAnimation {
                currentStep = .photos
            }
        case .photos:
            withAnimation {
                currentStep = .security
            }
        case .security:
            submitProfile()
        }
    }
    
    private func goBack() {
        errorMessage = nil
        withAnimation {
            switch currentStep {
            case .accountInfo:
                currentStep = .welcome
            case .profile:
                currentStep = .accountInfo
            case .photos:
                currentStep = .profile
            case .security:
                currentStep = .photos
            case .welcome:
                break
            }
        }
    }
    
    private func submitProfile() {
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords don't match"
            return
        }
        
        isSubmitting = true
        
        authManager.finishProfileSetup(
            username: username.trimmingCharacters(in: .whitespaces),
            bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
            fullName: fullName.trimmingCharacters(in: .whitespaces),
            password: password,
            profileImage: profileImage,
            coverImage: coverImage
        ) { success, error in
            isSubmitting = false
            
            if !success {
                errorMessage = error ?? "Something went wrong. Please try again."
            }
        }
    }
}

// MARK: - Password Requirement Row
struct PasswordRequirement: View {
    let text: String
    let met: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundColor(met ? .green : KHOIColors.mutedText)
            
            Text(text)
                .font(KHOITheme.caption)
                .foregroundColor(met ? KHOIColors.darkText : KHOIColors.mutedText)
        }
    }
}

// MARK: - Feature Row Component
struct FeatureRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(KHOIColors.accentBrown)
                .frame(width: 48, height: 48)
                .background(KHOIColors.accentBrown.opacity(0.1))
                .cornerRadius(12)
            
            Text(title)
                .font(KHOITheme.body)
                .foregroundColor(KHOIColors.darkText)
            
            Spacer()
        }
    }
}

// MARK: - Styled Text Field
struct StyledTextField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    let icon: String
    var disabled: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(KHOIColors.mutedText)
                Text(label)
                    .font(KHOITheme.callout)
                    .foregroundColor(KHOIColors.mutedText)
            }
            
            TextField(placeholder, text: $text)
                .font(KHOITheme.body)
                .foregroundColor(KHOIColors.darkText)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(disabled ? KHOIColors.chipBackground : KHOIColors.cardBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(KHOIColors.divider, lineWidth: 1)
                )
                .disabled(disabled)
        }
    }
}

// MARK: - Styled Secure Field
struct StyledSecureField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(KHOIColors.mutedText)
                Text(label)
                    .font(KHOITheme.callout)
                    .foregroundColor(KHOIColors.mutedText)
            }
            
            SecureField(placeholder, text: $text)
                .font(KHOITheme.body)
                .foregroundColor(KHOIColors.darkText)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(KHOIColors.cardBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(KHOIColors.divider, lineWidth: 1)
                )
        }
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Setup Image Cropper View
struct SetupImageCropperView: View {
    let image: UIImage
    let aspectRatio: CGFloat
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var displayImage: Image?
    
    var body: some View {
        GeometryReader { geometry in
            let safeTop = geometry.safeAreaInsets.top
            let safeBottom = geometry.safeAreaInsets.bottom
            let headerHeight: CGFloat = 60
            let footerHeight: CGFloat = 70
            
            ZStack {
                Color.black.ignoresSafeArea()
                
                let availableHeight = geometry.size.height - headerHeight - footerHeight
                let cropWidth = geometry.size.width - 40
                let cropHeight = min(cropWidth / aspectRatio, availableHeight - 40)
                
                // Image layer
                ZStack {
                    Color.black.opacity(0.5)
                    
                    Group {
                        if let displayImage = displayImage {
                            displayImage
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                    }
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = min(max(scale * delta, 1.0), 4.0)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    
                    Rectangle()
                        .strokeBorder(Color.white, lineWidth: 2)
                        .frame(width: cropWidth, height: cropHeight)
                        .allowsHitTesting(false)
                }
                .frame(width: geometry.size.width, height: availableHeight)
                .position(x: geometry.size.width / 2, y: safeTop + headerHeight + availableHeight / 2)
                
                // Header
                VStack {
                    HStack {
                        Button(action: { onCancel() }) {
                            Text("Cancel")
                                .font(KHOITheme.body)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Text("Adjust Photo")
                            .font(KHOITheme.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: { cropImage(geometry: geometry) }) {
                            Text("Done")
                                .font(KHOITheme.bodyBold)
                                .foregroundColor(KHOIColors.accentBrown)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, safeTop + 10)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
                    
                    Spacer()
                }
                
                // Footer
                VStack {
                    Spacer()
                    
                    Text("Pinch to zoom • Drag to reposition")
                        .font(KHOITheme.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(height: footerHeight)
                        .frame(maxWidth: .infinity)
                        .background(Color.black)
                        .padding(.bottom, safeBottom)
                }
                .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
        .onAppear {
            displayImage = Image(uiImage: image)
        }
    }
    
    private func cropImage(geometry: GeometryProxy) {
        let screenWidth = geometry.size.width
        let cropWidth = screenWidth - 40
        let cropHeight = cropWidth / aspectRatio
        
        let outputSize = CGSize(width: 1200, height: 1200 / aspectRatio)
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        
        let croppedImage = renderer.image { context in
            let imageSize = image.size
            let imageAspect = imageSize.width / imageSize.height
            let cropAspect = cropWidth / cropHeight
            
            var displayedWidth: CGFloat
            var displayedHeight: CGFloat
            
            if imageAspect > cropAspect {
                displayedHeight = cropHeight
                displayedWidth = displayedHeight * imageAspect
            } else {
                displayedWidth = cropWidth
                displayedHeight = displayedWidth / imageAspect
            }
            
            displayedWidth *= scale
            displayedHeight *= scale
            
            let drawX = (cropWidth - displayedWidth) / 2 + offset.width
            let drawY = (cropHeight - displayedHeight) / 2 + offset.height
            
            let scaleToOutput = outputSize.width / cropWidth
            let finalDrawRect = CGRect(
                x: drawX * scaleToOutput,
                y: drawY * scaleToOutput,
                width: displayedWidth * scaleToOutput,
                height: displayedHeight * scaleToOutput
            )
            
            image.draw(in: finalDrawRect)
        }
        
        onCrop(croppedImage)
    }
}

#Preview {
    ProfileSetupView()
        .environmentObject(AuthManager())
}
