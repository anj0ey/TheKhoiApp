//
//  EditProfileView.swift
//  TheKhoiApp
//
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
    
    // Cropper states
    @State private var showProfileCropper = false
    @State private var showCoverCropper = false
    @State private var tempProfileImage: UIImage? = nil
    @State private var tempCoverImage: UIImage? = nil
    
    // Loading states
    @State private var isSaving = false
    @State private var isUploadingProfile = false
    @State private var isUploadingCover = false
    @State private var isLoadingImage = false
    
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
            
            // Loading overlay
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
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("EDIT PROFILE")
                    .font(KHOITheme.headline)
                    .foregroundColor(KHOIColors.mutedText)
                    .tracking(2)
            }

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
                if let newItem = newItem {
                    isLoadingImage = true
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let originalImage = UIImage(data: data) {
                        // Resize BEFORE showing cropper
                        let resized = await Task.detached(priority: .userInitiated) {
                            return resizeImage(originalImage, maxDimension: 1500)
                        }.value
                        
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
                isLoadingImage = true
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let originalImage = UIImage(data: data) {
                    // Resize BEFORE showing cropper for better performance
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
        .fullScreenCover(isPresented: $showProfileCropper) {
            if let image = tempProfileImage {
                ImageCropperView(
                    image: image,
                    aspectRatio: 1.0,
                    onCrop: { croppedImage in
                        profileImage = croppedImage
                        uploadProfileImage(croppedImage)
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
                ImageCropperView(
                    image: image,
                    aspectRatio: 3.0,
                    onCrop: { croppedImage in
                        coverImage = croppedImage
                        uploadCoverImage(croppedImage)
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
    
    // MARK: - Cover Image Section
    private var coverImageSection: some View {
        ZStack(alignment: .bottomTrailing) {
            // Cover image
            if let coverImage = coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 160)
                    .clipped()
            } else if let coverURL = authManager.currentUser?.coverImageURL,
                      let url = URL(string: coverURL), !coverURL.isEmpty {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
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
            .disabled(isUploadingCover || isLoadingImage)
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
            .disabled(isUploadingProfile || isLoadingImage)
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
            EditProfileField(title: "Display name", text: $displayName)
            EditProfileField(title: "Username", text: $username)
                .textInputAutocapitalization(.never)
            EditProfileField(title: "Bio", text: $bio, isMultiline: true)
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

// MARK: - Optimized Image Cropper View
struct ImageCropperView: View {
    let image: UIImage
    let aspectRatio: CGFloat
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // Store the UIImage representation to avoid recreating it
    @State private var displayImage: Image?
    
    // Safe area for proper button positioning
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    
    var body: some View {
        GeometryReader { geometry in
            let safeTop = geometry.safeAreaInsets.top
            let safeBottom = geometry.safeAreaInsets.bottom
            let headerHeight: CGFloat = 60
            let footerHeight: CGFloat = 70
            
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                // MARK: - Crop Area (Middle section)
                let availableHeight = geometry.size.height - headerHeight - footerHeight
                let cropWidth = geometry.size.width - 40
                let cropHeight = min(cropWidth / aspectRatio, availableHeight - 40)
                
                // Image layer - only in the middle area
                ZStack {
                    // Dimmed background
                    Color.black.opacity(0.5)
                    
                    // The draggable/zoomable image
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
                    
                    // Crop frame overlay (non-interactive)
                    Rectangle()
                        .strokeBorder(Color.white, lineWidth: 2)
                        .frame(width: cropWidth, height: cropHeight)
                        .allowsHitTesting(false)
                    
                    // Corner handles (non-interactive)
                    VStack {
                        HStack {
                            cornerHandle()
                            Spacer()
                            cornerHandle()
                        }
                        Spacer()
                        HStack {
                            cornerHandle()
                            Spacer()
                            cornerHandle()
                        }
                    }
                    .frame(width: cropWidth, height: cropHeight)
                    .allowsHitTesting(false)
                }
                .frame(width: geometry.size.width, height: availableHeight)
                .position(x: geometry.size.width / 2, y: safeTop + headerHeight + availableHeight / 2)
                
                // MARK: - Fixed Header (Top)
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
                    .frame(height: headerHeight)
                    .background(Color.black)
                    
                    Spacer()
                }
                .ignoresSafeArea()
                .padding(.top, safeTop)
                
                // MARK: - Fixed Footer (Bottom)
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
    
    private func cornerHandle() -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white)
            .frame(width: 20, height: 20)
    }
    
    private func cropImage(geometry: GeometryProxy) {
        let screenWidth = geometry.size.width
        let cropWidth = screenWidth - 40
        let cropHeight = cropWidth / aspectRatio
        
        // Final output size
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

// MARK: - Safe Area Insets Environment
private struct SafeAreaInsetsKey: EnvironmentKey {
    static var defaultValue: EdgeInsets = EdgeInsets()
}

extension EnvironmentValues {
    var safeAreaInsets: EdgeInsets {
        get { self[SafeAreaInsetsKey.self] }
        set { self[SafeAreaInsetsKey.self] = newValue }
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
                    .scrollContentBackground(.hidden)
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
