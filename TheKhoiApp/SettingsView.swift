//
//  SettingsView.swift
//  TheKhoiApp
//
//  Settings with Edit Profile navigation
//

import SwiftUI
import SafariServices

// open link in app
struct SafariWebView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(KHOIColors.accentBrown)
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var pushNotifications = true
    @State private var marketingEmails = false
    
    // Delete account state
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    
    //Safari Viewing
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false

    private let privacyPolicyURL = URL(string: "https://cut-termite-d3e.notion.site/Privacy-Policy-for-KHOI-2c7c7965dce380b5a36ee7c5c168ccc5?source=copy_link")!
    private let termsOfServiceURL = URL(string: "https://cut-termite-d3e.notion.site/KHOI-Terms-and-Conditions-2d0c7965dce380d1b195dce0e5ae1aff?source=copy_link")!
    
    private func openSupportEmail() {
        let email = "khoiqnguyen27@gmail.com"
        let subject = "KHOI Support"
        let body = "Hi KHOI Team,"

        let mailtoString =
            "mailto:\(email)?subject=\(subject)&body=\(body)"

        if let encoded = mailtoString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: encoded) {
            UIApplication.shared.open(url)
        }
    }

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
                                    openSupportEmail()
                                } label: {
                                    SettingsChevronRow(title: "Contact Support")
                                }
                                
                                Divider()
                                
                                Button {
                                    showPrivacyPolicy = true
                                } label: {
                                    SettingsChevronRow(title: "Privacy Policy")
                                }
                                .sheet(isPresented: $showPrivacyPolicy) {
                                    SafariWebView(url: privacyPolicyURL)
                                }

                                
                                Divider()
                                
                                Button {
                                    showTermsOfService = true
                                } label: {
                                    SettingsChevronRow(title: "Terms of Service")
                                }
                                .sheet(isPresented: $showTermsOfService) {
                                    SafariWebView(url: termsOfServiceURL)
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
