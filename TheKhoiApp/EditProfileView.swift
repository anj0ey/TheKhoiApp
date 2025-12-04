//
//  EditProfileView.swift
//  TheKhoiApp
//
//  Edit profile with image upload support
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    // Form fields
    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var location: String = ""
    
    // Image picker state
    @State private var selectedProfileItem: PhotosPickerItem? = nil
    @State private var selectedCoverItem: PhotosPickerItem? = nil
    @State private var profileImage: UIImage? = nil
    @State private var coverImage: UIImage? = nil
    
    // Loading states
    @State private var isSaving = false
    @State private var isUploadingProfile = false
    @State private var isUploadingCover = false
    
    var body: some View {
        ZStack {
            KHOIColors.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: KHOITheme.spacing_lg) {
                    
                    // MARK: - Cover Image Section
                    coverImageSection
                    
                    // MARK: - Profile Picture Section
                    profilePictureSection
                        .offset(y: -50)
                        .padding(.bottom, -40)
                    
                    // MARK: - Form Fields
                    formFieldsSection
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("EDIT PROFILE")
                    .font(KHOITheme.headline)
                    .foregroundColor(KHOIColors.mutedText)
                    .tracking(2)
            }

            // Keep your Save button
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveProfile()
                }
                .font(KHOITheme.bodyBold)
                .foregroundColor(KHOIColors.accentBrown)
                .disabled(isSaving)
            }
        }

        .onAppear {
            loadExistingProfile()
        }
        .onChange(of: selectedProfileItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    profileImage = uiImage
                    uploadProfileImage(uiImage)
                }
            }
        }
        .onChange(of: selectedCoverItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    coverImage = uiImage
                    uploadCoverImage(uiImage)
                }
            }
        }
    }
    
    // MARK: - Cover Image Section
    private var coverImageSection: some View {
        ZStack(alignment: .bottomTrailing) {
            // Cover image
            if let coverImage = coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 160)
                    .clipped()
            } else if let coverURL = authManager.currentUser?.coverImageURL,
                      let url = URL(string: coverURL), !coverURL.isEmpty {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    defaultCoverGradient
                }
                .frame(height: 160)
                .clipped()
            } else {
                defaultCoverGradient
                    .frame(height: 160)
            }
            
            // Loading overlay
            if isUploadingCover {
                Color.black.opacity(0.4)
                    .frame(height: 160)
                    .overlay(ProgressView().tint(.white))
            }
            
            // Edit button
            PhotosPicker(selection: $selectedCoverItem, matching: .images) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(KHOIColors.accentBrown)
                    .clipShape(Circle())
            }
            .padding(12)
            .disabled(isUploadingCover)
        }
    }
    
    private var defaultCoverGradient: some View {
        LinearGradient(
            colors: [Color(hex: "8B4D5C"), Color(hex: "C4A07C")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Profile Picture Section
    private var profilePictureSection: some View {
        ZStack {
            Circle()
                .fill(KHOIColors.background)
                .frame(width: 100, height: 100)
            
            // Profile image
            if let profileImage = profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 92, height: 92)
                    .clipShape(Circle())
            } else if let profileURL = authManager.currentUser?.profileImageURL,
                      let url = URL(string: profileURL), !profileURL.isEmpty {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    defaultAvatar
                }
                .frame(width: 92, height: 92)
                .clipShape(Circle())
            } else {
                defaultAvatar
            }
            
            // Loading overlay
            if isUploadingProfile {
                Circle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 92, height: 92)
                    .overlay(ProgressView().tint(.white))
            }
            
            // Edit button
            PhotosPicker(selection: $selectedProfileItem, matching: .images) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(KHOIColors.accentBrown)
                    .clipShape(Circle())
            }
            .offset(x: 35, y: 35)
            .disabled(isUploadingProfile)
        }
    }
    
    private var defaultAvatar: some View {
        Circle()
            .fill(KHOIColors.chipBackground)
            .frame(width: 92, height: 92)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 36))
                    .foregroundColor(KHOIColors.mutedText)
            )
    }
    
    // MARK: - Form Fields Section
    private var formFieldsSection: some View {
        VStack(spacing: KHOITheme.spacing_md) {
            // Display Name
            EditProfileField(title: "Display name", text: $displayName)
            
            // Username
            EditProfileField(title: "Username", text: $username)
                .textInputAutocapitalization(.never)
            
            // Bio
            EditProfileField(title: "Bio", text: $bio, isMultiline: true)
            
            // Location
            EditProfileField(title: "Location", text: $location)
        }
        .padding(.horizontal, KHOITheme.spacing_md)
    }
    
    // MARK: - Actions
    
    private func loadExistingProfile() {
        guard let user = authManager.currentUser else { return }
        displayName = user.fullName
        username = user.username
        bio = user.bio
        location = user.location ?? ""
    }
    
    private func saveProfile() {
        isSaving = true
        
        authManager.updateProfile(
            fullName: displayName,
            username: username,
            bio: bio,
            location: location
        ) { success in
            isSaving = false
            if success {
                dismiss()
            }
        }
    }
    
    private func uploadProfileImage(_ image: UIImage) {
        isUploadingProfile = true
        authManager.uploadProfileImage(image) { success in
            isUploadingProfile = false
            if !success {
                print("Failed to upload profile image")
            }
        }
    }
    
    private func uploadCoverImage(_ image: UIImage) {
        isUploadingCover = true
        authManager.uploadCoverImage(image) { success in
            isUploadingCover = false
            if !success {
                print("Failed to upload cover image")
            }
        }
    }
}

// MARK: - Edit Profile Field Component
struct EditProfileField: View {
    let title: String
    @Binding var text: String
    var isMultiline: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: KHOITheme.spacing_xs) {
            Text(title.uppercased())
                .font(KHOITheme.captionUppercase)
                .foregroundColor(KHOIColors.mutedText)
                .tracking(1)
            
            if isMultiline {
                TextEditor(text: $text)
                    .font(KHOITheme.body)
                    .frame(minHeight: 80)
                    .padding(12)
                    .background(KHOIColors.cardBackground)
                    .cornerRadius(KHOITheme.radius_lg)
            } else {
                TextField("", text: $text)
                    .font(KHOITheme.body)
                    .padding(14)
                    .background(KHOIColors.cardBackground)
                    .cornerRadius(KHOITheme.radius_lg)
            }
        }
    }
}

#Preview {
    NavigationStack {
        EditProfileView()
            .environmentObject(AuthManager())
    }
}
