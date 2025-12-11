//
//  ProfileSetupView.swift
//  TheKhoiApp
//
//

import SwiftUI

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
    
    @State private var errorMessage: String?
    @State private var isSubmitting: Bool = false
    @State private var showLogoutConfirmation: Bool = false
    
    enum OnboardingStep {
        case welcome
        case accountInfo
        case profile
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
            ForEach(0..<3) { index in
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
        case .security: return 3
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
                                .foregroundColor(KHOIColors.mutedText.opacity(0.5))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                        }
                        
                        TextEditor(text: $bio)
                            .font(KHOITheme.body)
                            .foregroundColor(KHOIColors.darkText)
                            .frame(minHeight: 120)
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
    
    // MARK: - Security Step
    private var securityStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Secure Your Account")
                    .font(KHOITheme.title)
                    .foregroundColor(KHOIColors.darkText)
                
                Text("Create a password for your account. Make it strong!")
                    .font(KHOITheme.callout)
                    .foregroundColor(KHOIColors.mutedText)
            }
            
            VStack(spacing: 16) {
                StyledSecureField(
                    label: "Password",
                    text: $password,
                    placeholder: "At least 6 characters",
                    icon: "lock"
                )
                
                StyledSecureField(
                    label: "Confirm Password",
                    text: $confirmPassword,
                    placeholder: "Re-enter password",
                    icon: "lock.fill"
                )
                
                // Password strength indicator
                if !password.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(0..<4) { index in
                            Rectangle()
                                .fill(index < passwordStrength ? strengthColor : KHOIColors.chipBackground)
                                .frame(height: 4)
                                .cornerRadius(2)
                        }
                    }
                    
                    Text(strengthText)
                        .font(KHOITheme.caption)
                        .foregroundColor(strengthColor)
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
        case .security: return isSubmitting ? "Creating Account..." : "Complete Setup"
        }
    }
    
    private var isButtonEnabled: Bool {
        switch currentStep {
        case .welcome: return true
        case .accountInfo: return !fullName.trimmingCharacters(in: .whitespaces).isEmpty
        case .profile: return !username.trimmingCharacters(in: .whitespaces).isEmpty
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
            case .security:
                currentStep = .profile
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
            password: password
        ) { success, error in
            isSubmitting = false
            
            if !success {
                errorMessage = error ?? "Something went wrong. Please try again."
            }
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

#Preview {
    ProfileSetupView()
        .environmentObject(AuthManager())
}
