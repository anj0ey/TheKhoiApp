//
//  SettingsView.swift
//  TheKhoiApp
//
//  Created by Paige McNamara-Pittler on 12/2/25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var pushNotifications = true
    @State private var darkMode = false
    @State private var marketingEmails = false

    var body: some View {
        ZStack {
            KHOIColors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: KHOITheme.spacing_lg) {

                    // MARK: - Title
                    Text("Settings")
                        .font(KHOITheme.heading2)
                        .foregroundColor(KHOIColors.darkText)
                        .padding(.horizontal, KHOITheme.spacing_md)
                        .padding(.top, KHOITheme.spacing_md)

                    // MARK: - Account Section
                    VStack(alignment: .leading, spacing: KHOITheme.spacing_sm) {
                        Text("Account")
                            .font(KHOITheme.captionUppercase)
                            .foregroundColor(KHOIColors.mutedText)
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
                                }

                                Button {
                                    // TODO: Navigate to Edit Profile screen when implemented
                                } label: {
                                    SettingsChevronRow(title: "Edit profile")
                                }
                            }
                        }
                    }

                    // MARK: - Preferences Section
                    VStack(alignment: .leading, spacing: KHOITheme.spacing_sm) {
                        Text("Preferences")
                            .font(KHOITheme.captionUppercase)
                            .foregroundColor(KHOIColors.mutedText)
                            .padding(.horizontal, KHOITheme.spacing_md)

                        SettingsCard {
                            VStack(spacing: 0) {
                                SettingsToggleRow(
                                    title: "Push notifications",
                                    isOn: $pushNotifications
                                )

                                Divider()

                                SettingsToggleRow(
                                    title: "Dark mode",
                                    isOn: $darkMode
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
                        Text("Support")
                            .font(KHOITheme.captionUppercase)
                            .foregroundColor(KHOIColors.mutedText)
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
                            }
                        }
                    }

                    // MARK: - Log Out
                    Button(role: .destructive) {
                        authManager.logOut()
                    } label: {
                        Text("Log out")
                            .font(KHOITheme.bodyBold)
                            .foregroundColor(KHOIColors.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, KHOITheme.spacing_md)
                    }
                    .padding(.horizontal, KHOITheme.spacing_md)
                    .padding(.top, KHOITheme.spacing_sm)

                    Spacer(minLength: KHOITheme.spacing_xl)
                }
            }
        }
        // When pushed from a NavigationStack, this will show in the nav bar;
        // the big text at the top visually matches the Figma layout.
        .navigationBarTitleDisplayMode(.inline)
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
