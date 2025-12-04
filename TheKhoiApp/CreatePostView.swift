//
//  CreatePostView.swift
//  TheKhoiApp
//
//  Created by Paige McNamara-Pittler on 12/2/25.
//

import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct CreatePostView: View {
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var feedService = FeedService()
    @State private var isUploading = false
    
    // Image picker
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    
    // Form values
    @State private var caption: String = ""
    @State private var selectedCategory: String? = nil
    @State private var taggedProvider: String = ""
    
    private let categories = ["Hair", "Nails", "Makeup", "Brows", "Skin", "Body", "Lash"]
    
    var body: some View {
        ZStack {
            KHOIColors.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: KHOITheme.spacing_lg) {
                    Spacer()

                    // MARK: - Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .font(KHOITheme.body)
                                .foregroundColor(KHOIColors.mutedText)
                        }
                        
                        Spacer()
                        
                        Text("NEW POST")
                            .font(KHOITheme.headline)
                            .foregroundColor(KHOIColors.mutedText)
                            .tracking(2)
                        
                        Spacer()
                        
                        Button(action: sharePost) {
                            if isUploading {
                                ProgressView()
                            } else {
                                Text("Share").font(KHOITheme.bodyBold)
                                    .foregroundColor(canShare ? KHOIColors.accentBrown : Color.gray)
                            }
                        }
                        .disabled(!canShare || isUploading) // Disable button if empty OR if busy
                    }
                    .padding(.horizontal, KHOITheme.spacing_md)
                    .padding(.top, KHOITheme.spacing_md)
                    
                    // MARK: - Image picker card
                    VStack(alignment: .leading, spacing: KHOITheme.spacing_sm) {
                        Text("Photo")
                            .font(KHOITheme.captionUppercase)
                            .foregroundColor(KHOIColors.mutedText)
                        
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            ZStack {
                                RoundedRectangle(cornerRadius: KHOITheme.radius_lg)
                                    .fill(KHOIColors.cardBackground)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 253)
                                
                                if let image = selectedImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 253)
                                        .clipped()
                                        .cornerRadius(KHOITheme.radius_lg)
                                } else {
                                    VStack(spacing: KHOITheme.spacing_sm) {
                                        Image(systemName: "photo.on.rectangle.angled")
                                            .font(.system(size: 32))
                                            .foregroundColor(KHOIColors.mutedText)
                                        Text("Tap to add a photo")
                                            .font(KHOITheme.body)
                                            .foregroundColor(KHOIColors.mutedText)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, KHOITheme.spacing_md)
                    
                    // MARK: - Caption
                    VStack(alignment: .leading, spacing: KHOITheme.spacing_xs) {
                        Text("Caption")
                            .font(KHOITheme.captionUppercase)
                            .foregroundColor(KHOIColors.mutedText)
                        
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: KHOITheme.radius_lg)
                                .fill(KHOIColors.cardBackground)
                            
                            TextEditor(text: $caption)
                                .font(KHOITheme.body)
                                .padding(.horizontal, KHOITheme.spacing_md)
                                .padding(.vertical, KHOITheme.spacing_sm)
                                .frame(minHeight: 100, alignment: .topLeading)
                            
                            if caption.isEmpty {
                                Text("Write a caption…")
                                    .font(KHOITheme.body)
                                    .foregroundColor(KHOIColors.mutedText)
                                    .padding(.horizontal, KHOITheme.spacing_md + 2)
                                    .padding(.vertical, KHOITheme.spacing_sm + 3)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, KHOITheme.spacing_md)
                    
                    // MARK: - Tag provider
                    VStack(alignment: .leading, spacing: KHOITheme.spacing_xs) {
                        Text("Tag provider")
                            .font(KHOITheme.captionUppercase)
                            .foregroundColor(KHOIColors.mutedText)
                        
                        RoundedRectangle(cornerRadius: KHOITheme.radius_lg)
                            .fill(KHOIColors.cardBackground)
                            .overlay(
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(KHOIColors.mutedText)
                                    
                                    TextField("Search provider", text: $taggedProvider)
                                        .font(KHOITheme.body)
                                        .autocorrectionDisabled()
                                    
                                    Spacer()
                                }
                                    .padding(.horizontal, KHOITheme.spacing_md)
                                    .padding(.vertical, KHOITheme.spacing_sm)
                            )
                            .frame(height: 48)
                    }
                    .padding(.horizontal, KHOITheme.spacing_md)
                    
                    // MARK: - Category chips
                    VStack(alignment: .leading, spacing: KHOITheme.spacing_xs) {
                        Text("Beauty Service")
                            .font(KHOITheme.captionUppercase)
                            .foregroundColor(KHOIColors.mutedText)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: KHOITheme.spacing_sm) {
                                ForEach(categories, id: \.self) { category in
                                    Button {
                                        if selectedCategory == category {
                                            selectedCategory = nil
                                        } else {
                                            selectedCategory = category
                                        }
                                    } label: {
                                        Text(category)
                                            .font(KHOITheme.caption)
                                            .padding(.horizontal, KHOITheme.spacing_md)
                                            .padding(.vertical, 8)
                                            .background(
                                                selectedCategory == category
                                                ? KHOIColors.accent.opacity(0.15)
                                                : KHOIColors.cardBackground
                                            )
                                            .foregroundColor(
                                                selectedCategory == category
                                                ? KHOIColors.accent
                                                : KHOIColors.darkText
                                            )
                                            .cornerRadius(999)
                                    }
                                }
                            }
                            .padding(.horizontal, KHOITheme.spacing_md)
                        }
                    }
                    .padding(.horizontal, KHOITheme.spacing_md)
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                guard let newItem else { return }
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedImage = uiImage
                }
            }
        }
    }
    
    // MARK: - Derived state
    
    private var canShare: Bool {
        selectedImage != nil && !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Actions
    
    private func sharePost() {
        guard let image = selectedImage,
              let user = authManager.currentUser,
              let uid = authManager.firebaseUID else { return }
        
        isUploading = true
        let path = "post_images/\(UUID().uuidString).jpg"
        
        // 1. Upload Image
        feedService.uploadImage(image: image, path: path) { result in
            switch result {
            case .success(let url):
                
                // 2. Create Post (FIXED: Added UUID for id)
                let newPost = Post(
                    id: UUID().uuidString,
                    artistId: uid,
                    artistName: user.fullName,
                    artistHandle: "@\(user.username)",
                    artistProfileImageURL: nil,
                    imageURL: url,
                    imageHeight: 350,
                    tag: selectedCategory ?? "General",
                    caption: caption,
                    saveCount: 0,
                    createdAt: Date()
                )
                
                // 3. Upload Post (FIXED: Handling Result<String, Error>)
                feedService.uploadPost(newPost) { result in
                    isUploading = false
                    switch result {
                    case .success:
                        dismiss()
                    case .failure(let error):
                        print("Error: \(error.localizedDescription)")
                    }
                }
                
            case .failure(let error):
                isUploading = false
                print("Image upload failed: \(error)")
            }
        }
    }}

#Preview {
    NavigationStack {
        CreatePostView()
    }
}
