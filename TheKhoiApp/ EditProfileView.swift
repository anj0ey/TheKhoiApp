//
//  EditProfileView.swift
//  TheKhoiApp
//
//  Created by Paige McNamara-Pittler on 12/2/25.
//  FIXED: Resolved generic parameter, type conversion, and optional property issues
//

import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var location: String = ""

    var body: some View {
        ZStack {
            KHOIColors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: KHOITheme.spacing_lg) {

                    // Title
                    HStack {
                        Text("Edit profile")
                            .font(KHOITheme.heading2)
                            .foregroundColor(KHOIColors.darkText)
                        Spacer()
                    }
                    .padding(.horizontal, KHOITheme.spacing_md)
                    .padding(.top, KHOITheme.spacing_md)

                    // Avatar / header
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(KHOIColors.cardBackground)
                                .frame(width: 88, height: 88)

                            Image(systemName: "person.fill")
                                .font(.system(size: 32))
                                .foregroundColor(KHOIColors.mutedText)

                            Circle()
                                .fill(KHOIColors.accent)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                )
                                .offset(x: 30, y: 30)
                        }
                        Spacer()
                    }

                    // Form fields card
                    VStack(spacing: KHOITheme.spacing_md) {
                        SettingsFieldSection(
                            title: "Display name",
                            content: {
                                TextField("Display name", text: $displayName)
                                    .textFieldStyle(.plain)
                                    .font(KHOITheme.body)
                            }
                        )

                        SettingsFieldSection(
                            title: "Username",
                            content: {
                                TextField("Username", text: $username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .textFieldStyle(.plain)
                                    .font(KHOITheme.body)
                            }
                        )

                        SettingsFieldSection(
                            title: "Bio",
                            content: {
                                TextEditor(text: $bio)
                                    .font(KHOITheme.body)
                                    .frame(minHeight: 90, alignment: .topLeading)
                            }
                        )

                        SettingsFieldSection(
                            title: "Location",
                            content: {
                                TextField("City, State", text: $location)
                                    .textFieldStyle(.plain)
                                    .font(KHOITheme.body)
                            }
                        )
                    }
                    .padding(.horizontal, KHOITheme.spacing_md)

                    Spacer(minLength: 40)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveProfile()
                }
                .font(KHOITheme.bodyBold)
            }
        }
        .onAppear {
            loadExistingProfile()
        }
    }

    private func loadExistingProfile() {
        guard let user = authManager.currentUser else { return }
        displayName = user.fullName
        username = user.username
        bio = user.bio
        location = user.location ?? ""
    }

    private func saveProfile() {
        // TODO: Connect this to AuthManager / backend once ready.
        // For now you could update authManager.currentUser in memory.
    }
}

// MARK: - Small helper for labeled fields
// FIXED: Changed @ViewBuilder to a closure parameter

private struct SettingsFieldSection<Content: View>: View {
    let title: String
    let content: () -> Content  // FIXED: Changed from @ViewBuilder to closure

    var body: some View {
        VStack(alignment: .leading, spacing: KHOITheme.spacing_xs) {
            Text(title)
                .font(KHOITheme.captionUppercase)
                .foregroundColor(KHOIColors.mutedText)
                .textCase(.uppercase)  // Added to make the uppercase work properly

            VStack {
                content()  // FIXED: Call the closure
                    .padding(.vertical, KHOITheme.spacing_sm)
                    .padding(.horizontal, KHOITheme.spacing_md)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KHOIColors.cardBackground)
            .cornerRadius(KHOITheme.radius_lg)
        }
    }
}

#Preview {
    NavigationStack {
        EditProfileView()
            .environmentObject(AuthManager())
    }
}
