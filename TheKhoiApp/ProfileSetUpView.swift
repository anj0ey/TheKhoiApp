//
//  ProfileSetUpView.swift
//  TheKhoiApp
//
//  Created by iya student on 12/1/25.
//

import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""

    @State private var errorMessage: String?
    @State private var isSubmitting: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: KHOITheme.spacing_lg) {

                        Text("Create your profile")
                            .font(KHOITheme.title)
                            .foregroundColor(KHOIColors.darkText)
                            .padding(.top, KHOITheme.spacing_xl)

                        Group {
                            labeledField("Full name", text: $fullName, disabled: true)
                            labeledField("Email", text: $email, disabled: true)

                            labeledField("Username", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                            labeledSecureField("Password", text: $password)
                            labeledSecureField("Confirm password", text: $confirmPassword)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Bio")
                                    .font(KHOITheme.callout)
                                    .foregroundColor(KHOIColors.mutedText)

                                TextEditor(text: $bio)
                                    .frame(minHeight: 120)
                                    .padding(10)
                                    .background(KHOIColors.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md))
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(KHOITheme.caption)
                                .foregroundColor(.red)
                        }

                        Button {
                            submit()
                        } label: {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(isSubmitting ? "Saving..." : "Finish setup")
                                    .font(KHOITheme.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, KHOITheme.spacing_lg)
                            .background(isSubmitting ? KHOIColors.accentBrown.opacity(0.6) : KHOIColors.accentBrown)
                            .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md))
                        }
                        .disabled(isSubmitting)
                        .padding(.top, KHOITheme.spacing_md)

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, KHOITheme.spacing_xl)
                }
            }
            .navigationBarBackButtonHidden(true)
            .onAppear {
                fullName = authManager.authenticatedName ?? ""
                email = authManager.authenticatedEmail ?? ""
                print("📱 ProfileSetup appeared")
                print("   Name:", fullName)
                print("   Email:", email)
                print("   Firebase UID:", authManager.firebaseUID ?? "nil")
            }
        }
    }

    private func submit() {
        errorMessage = nil
        isSubmitting = true

        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please choose a username."
            isSubmitting = false
            return
        }

        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            isSubmitting = false
            return
        }

        guard password == confirmPassword else {
            errorMessage = "Passwords don't match."
            isSubmitting = false
            return
        }

        print("📤 Submitting profile setup...")
        
        authManager.finishProfileSetup(
            username: username.trimmingCharacters(in: .whitespaces),
            bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        ) { success, error in
            isSubmitting = false
            
            if success {
                print("✅ Profile setup completed successfully")
            } else {
                print("❌ Profile setup failed:", error ?? "Unknown error")
                errorMessage = error ?? "Something went wrong. Please try again."
            }
        }
    }

    private func labeledField(_ title: String, text: Binding<String>, disabled: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(KHOITheme.callout)
                .foregroundColor(KHOIColors.mutedText)

            TextField("", text: text)
                .disabled(disabled)
                .padding()
                .background(KHOIColors.cardBackground.opacity(disabled ? 0.6 : 1))
                .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md))
        }
    }

    private func labeledSecureField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(KHOITheme.callout)
                .foregroundColor(KHOIColors.mutedText)

            SecureField("", text: text)
                .padding()
                .background(KHOIColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md))
        }
    }
}
