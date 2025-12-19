//
//  SettingsView.swift
//  TheKhoiApp
//
//  Settings with Edit Profile navigation
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var pushNotifications = true
    @State private var marketingEmails = false
    
    // Delete account state
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    var body: some View {
        ZStack {
            KHOIColors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: KHOITheme.spacing_lg) {
                    
                    Spacer()
                    
                    // MARK: - Title
                    HStack {
                        Text("SETTINGS")
                            .font(KHOITheme.headline)
                            .foregroundColor(KHOIColors.mutedText)
                            .tracking(2)
                        
                        Spacer()
                        
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(KHOIColors.mutedText)
                                .padding(8)
                                .background(KHOIColors.chipBackground)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, KHOITheme.spacing_md)
                    .padding(.top, KHOITheme.spacing_md)

                    // MARK: - Account Section
                    VStack(alignment: .leading, spacing: KHOITheme.spacing_sm) {
                        Text("ACCOUNT")
                            .font(KHOITheme.captionUppercase)
                            .foregroundColor(KHOIColors.mutedText)
                            .tracking(1)
                            .padding(.horizontal, KHOITheme.spacing_md)

                        SettingsCard {
                            VStack(spacing: 0) {
                                if let user = authManager.currentUser {
                                    SettingsValueRow(
                                        title: "Name",
                                        value: user.fullName
                                    )

                                    Divider()

                                    SettingsValueRow(
                                        title: "Username",
                                        value: "@\(user.username)"
                                    )

                                    Divider()
                                    
                                    SettingsValueRow(
                                        title: "Email",
                                        value: user.email
                                    )

                                    Divider()
                                }

                                NavigationLink(destination: EditProfileView().environmentObject(authManager)) {
                                    SettingsChevronRow(title: "Edit profile")
                                }
                            }
                        }
                    }

                    // MARK: - Preferences Section
                    VStack(alignment: .leading, spacing: KHOITheme.spacing_sm) {
                        Text("PREFERENCES")
                            .font(KHOITheme.captionUppercase)
                            .foregroundColor(KHOIColors.mutedText)
                            .tracking(1)
                            .padding(.horizontal, KHOITheme.spacing_md)

                        SettingsCard {
                            VStack(spacing: 0) {
                                SettingsToggleRow(
                                    title: "Push notifications",
                                    isOn: $pushNotifications
                                )

                                Divider()

                                SettingsToggleRow(
                                    title: "Marketing emails",
                                    isOn: $marketingEmails
                                )
                            }
                        }
                    }

                    // MARK: - Support Section
                    VStack(alignment: .leading, spacing: KHOITheme.spacing_sm) {
                        Text("SUPPORT")
                            .font(KHOITheme.captionUppercase)
                            .foregroundColor(KHOIColors.mutedText)
                            .tracking(1)
                            .padding(.horizontal, KHOITheme.spacing_md)

                        SettingsCard {
                            VStack(spacing: 0) {
                                Button {
                                    // TODO: Link to Help / FAQ
                                } label: {
                                    SettingsChevronRow(title: "Help & FAQ")
                                }

                                Divider()

                                Button {
                                    // TODO: Open contact support flow
                                } label: {
                                    SettingsChevronRow(title: "Contact support")
                                }
                                
                                Divider()
                                
                                Button {
                                    // TODO: Privacy policy
                                } label: {
                                    SettingsChevronRow(title: "Privacy policy")
                                }
                                
                                Divider()
                                
                                Button {
                                    // TODO: Terms of service
                                } label: {
                                    SettingsChevronRow(title: "Terms of service")
                                }
                            }
                        }
                    }

                    // MARK: - Log Out
                    Button(role: .destructive) {
                        authManager.logOut()
                        dismiss()
                    } label: {
                        Text("Log out")
                            .font(KHOITheme.bodyBold)
                            .foregroundColor(KHOIColors.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, KHOITheme.spacing_md)
                            .background(KHOIColors.cardBackground)
                            .cornerRadius(KHOITheme.radius_lg)
                    }
                    .padding(.horizontal, KHOITheme.spacing_md)
                    .padding(.top, KHOITheme.spacing_sm)
                    
                    // MARK: - Delete Account
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            if isDeleting {
                                ProgressView()
                                    .tint(KHOIColors.danger)
                                    .scaleEffect(0.8)
                            }
                            Text(isDeleting ? "Deleting..." : "Delete account")
                                .font(KHOITheme.body)
                                .foregroundColor(KHOIColors.danger.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KHOITheme.spacing_sm)
                    }
                    .disabled(isDeleting)
                    .padding(.horizontal, KHOITheme.spacing_md)
                    
                    // Error message
                    if let error = deleteError {
                        Text(error)
                            .font(KHOITheme.caption)
                            .foregroundColor(KHOIColors.danger)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, KHOITheme.spacing_md)
                    }

                    Spacer(minLength: KHOITheme.spacing_xl)
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Delete Account", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently removed.")
        }
    }
    
    // MARK: - Delete Account Action
    
    private func deleteAccount() {
        isDeleting = true
        deleteError = nil
        
        authManager.deleteAccount { success, error in
            isDeleting = false
            
            if success {
                dismiss()
            } else {
                deleteError = error
            }
        }
    }
}

// MARK: - Reusable components

private struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack {
            content
        }
        .padding(.horizontal, KHOITheme.spacing_md)
        .padding(.vertical, KHOITheme.spacing_sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KHOIColors.cardBackground)
        .cornerRadius(KHOITheme.radius_lg)
        .padding(.horizontal, KHOITheme.spacing_md)
    }
}

private struct SettingsChevronRow: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(KHOITheme.body)
                .foregroundColor(KHOIColors.darkText)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(KHOIColors.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, KHOITheme.spacing_sm)
    }
}

private struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(KHOITheme.body)
                .foregroundColor(KHOIColors.mutedText)

            Spacer()

            Text(value)
                .font(KHOITheme.body)
                .foregroundColor(KHOIColors.darkText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, KHOITheme.spacing_sm)
    }
}

private struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(KHOITheme.body)
                .foregroundColor(KHOIColors.darkText)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(KHOIColors.accentBrown)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, KHOITheme.spacing_sm)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AuthManager())
    }
}
