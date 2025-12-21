//
//  OnboardingView.swift
//  TheKhoiApp
//
//  Updated with Email authentication instead of Apple Sign In
//

import SwiftUI
import GoogleSignIn

// MARK: - Onboarding View
struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthManager
    
    @State private var email: String = ""
    @State private var showPasswordSheet: Bool = false
    
    var body: some View {
        ZStack {
            KHOIColors.white.ignoresSafeArea()
            
            Image("background")
                .resizable()
                .scaledToFit()
                .offset(y: 350)
                .ignoresSafeArea()
                .zIndex(0)
            
            LinearGradient(
                colors: [Color.white, Color.white.opacity(0)],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
            .zIndex(1)
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo and tagline
                VStack(spacing: KHOITheme.spacing_md) {
                    Text("KHOI")
                        .font(KHOITheme.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(KHOIColors.darkText)
                        .tracking(2)
                    
                    Text("where beauty finds you.")
                        .font(KHOITheme.title2)
                        .foregroundColor(KHOIColors.mutedText)
                        .tracking(2)
                }
                .padding(.bottom, KHOITheme.spacing_xxl)
                
                // Auth buttons
                VStack(spacing: KHOITheme.spacing_md) {
                    // Email input field
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope")
                                .font(.system(size: 18))
                                .foregroundColor(KHOIColors.mutedText)
                            
                            TextField("Enter your email", text: $email)
                                .font(KHOITheme.body)
                                .foregroundColor(KHOIColors.darkText)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(KHOIColors.cardBackground)
                        .cornerRadius(KHOITheme.cornerRadius_md)
                        .overlay(
                            RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md)
                                .stroke(KHOIColors.divider, lineWidth: 1)
                        )
                    }
                    
                    // Continue with Email button
                    Button {
                        continueWithEmail()
                    } label: {
                        HStack(spacing: KHOITheme.spacing_md) {
                            if authManager.isEmailLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                            } else {
                                Text("Continue with Email")
                                    .font(KHOITheme.headline)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KHOITheme.spacing_lg)
                        .background(isValidEmail ? KHOIColors.darkText : KHOIColors.mutedText)
                        .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md))
                    }
                    .disabled(!isValidEmail || authManager.isEmailLoading)
                    
                    // Error message
                    if let error = authManager.emailAuthError {
                        Text(error)
                            .font(KHOITheme.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Divider with "or"
                    HStack(spacing: 16) {
                        Rectangle()
                            .fill(KHOIColors.divider)
                            .frame(height: 1)
                        
                        Text("or")
                            .font(KHOITheme.caption)
                            .foregroundColor(KHOIColors.mutedText)
                        
                        Rectangle()
                            .fill(KHOIColors.divider)
                            .frame(height: 1)
                    }
                    .padding(.vertical, 8)
                    
                    // Continue with Google button
                    Button {
                        authManager.signInWithGoogle()
                    } label: {
                        HStack(spacing: KHOITheme.spacing_md) {
                            Image(systemName: "globe")
                                .font(.title3)
                            Text("Continue with Google")
                                .font(KHOITheme.headline)
                        }
                        .foregroundColor(KHOIColors.darkText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KHOITheme.spacing_lg)
                        .background(KHOIColors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md)
                                .stroke(KHOIColors.divider, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md))
                    }
                }
                .padding(.horizontal, KHOITheme.spacing_xl)
                
                Text("By continuing, you agree to our Privacy Policy and Terms and Conditions")
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.mutedText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, KHOITheme.spacing_xl)
                    .padding(.top, KHOITheme.spacing_lg)
                    .padding(.bottom, KHOITheme.spacing_xxl)
                
                Spacer()
            }
            .zIndex(2)
        }
        .sheet(isPresented: $showPasswordSheet) {
            PasswordEntrySheet(
                email: email,
                onDismiss: { showPasswordSheet = false }
            )
            .environmentObject(authManager)
        }
    }
    
    // MARK: - Helpers
    
    private var isValidEmail: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: trimmed)
    }
    
    private func continueWithEmail() {
        authManager.continueWithEmail(email: email) { success, existingUser in
            if success {
                if existingUser {
                    // Existing user - show password sheet to sign in
                    self.showPasswordSheet = true
                } else {
                    // New user - go directly to ProfileSetupView
                    // Set the email and trigger profile setup
                    authManager.startNewUserProfileSetup(email: email)
                }
            }
        }
    }
}

// MARK: - Password Entry Sheet (Only for existing users now)
struct PasswordEntrySheet: View {
    let email: String
    let onDismiss: () -> Void
    
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var localError: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(KHOIColors.accentBrown)
                        
                        Text("Welcome Back!")
                            .font(KHOITheme.title)
                            .foregroundColor(KHOIColors.darkText)
                        
                        Text(email)
                            .font(KHOITheme.callout)
                            .foregroundColor(KHOIColors.mutedText)
                    }
                    .padding(.top, 32)
                    
                    // Password field
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(KHOITheme.callout)
                                .foregroundColor(KHOIColors.mutedText)
                            
                            HStack {
                                if showPassword {
                                    TextField("Enter password", text: $password)
                                        .textContentType(.password)
                                } else {
                                    SecureField("Enter password", text: $password)
                                        .textContentType(.password)
                                }
                                
                                Button(action: { showPassword.toggle() }) {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(KHOIColors.mutedText)
                                }
                            }
                            .font(KHOITheme.body)
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
                    .padding(.horizontal, 24)
                    
                    // Error message
                    if let error = localError ?? authManager.emailAuthError {
                        Text(error)
                            .font(KHOITheme.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                    
                    // Sign In button
                    Button(action: handleSignIn) {
                        HStack {
                            if authManager.isEmailLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                            } else {
                                Text("Sign In")
                                    .font(KHOITheme.headline)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(password.count >= 6 ? KHOIColors.accentBrown : KHOIColors.mutedText)
                        .cornerRadius(12)
                    }
                    .disabled(password.count < 6 || authManager.isEmailLoading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        onDismiss()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(KHOIColors.darkText)
                            .padding(8)
                            .background(KHOIColors.chipBackground)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    private func handleSignIn() {
        localError = nil
        
        authManager.signInOrCreateAccount(email: email, password: password) { success, error, shouldCreateNewAccount in
            if success {
                dismiss()
            } else if shouldCreateNewAccount {
                // User exists in Firestore but not in Firebase Auth (orphaned record)
                // Dismiss and redirect to profile setup as new user
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    authManager.startNewUserProfileSetup(email: email)
                }
            } else {
                localError = error
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthManager())
}
