//
//  EditProfileView.swift
//  TheKhoiApp
//
//  Created by Paige McNamara-Pittler on 12/2/25.
//

import SwiftUI
import FirebaseFirestore

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
                            content: TextField("Display name", text: $displayName)
                                .textFieldStyle(.plain)
                                .font(KHOITheme.body)
                        )

                        SettingsFieldSection(
                            title: "Username",
                            content: TextField("Username", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textFieldStyle(.plain)
                                .font(KHOITheme.body)
                        )

                        SettingsFieldSection(
                            title: "Bio",
                            content: TextEditor(text: $bio)
                                .font(KHOITheme.body)
                                .frame(minHeight: 90, alignment: .topLeading)
                        )

                        SettingsFieldSection(
                            title: "Location",
                            content: TextField("City, State", text: $location)
                                .textFieldStyle(.plain)
                                .font(KHOITheme.body)
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
        bio = user.bio ?? ""
        location = user.location ?? ""
    }

    private func saveProfile() {
        guard let uid = authManager.firebaseUID else { return }
        
        let db = Firestore.firestore()
        
        // Update the 'users' collection
        db.collection("users").document(uid).updateData([
            "fullName": displayName,
            "username": username,
            "bio": bio,
            "location": location // Ensure your UserProfile model has this field, or remove it
        ]) { error in
            if let error = error {
                print("Error saving profile: \(error)")
            } else {
                print("Profile updated!")
                // You might want to refresh AuthManager local user data here
            }
        }
    }
}

// MARK: - Small helper for labeled fields

private struct SettingsFieldSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: KHOITheme.spacing_xs) {
            Text(title)
                .font(KHOITheme.captionUppercase)
                .foregroundColor(KHOIColors.mutedText)

            VStack {
                content
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
