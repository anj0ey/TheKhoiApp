// AdminUploadView.swift

import SwiftUI
import PhotosUI
import FirebaseStorage

struct AdminUploadView: View {
    @StateObject private var feedService = FeedService()
    
    // Artist fields
    @State private var artistName = ""
    @State private var artistUsername = ""
    @State private var artistBio = ""
    @State private var artistCity = ""
    @State private var artistInstagram = ""
    @State private var selectedServices: Set<String> = []
    @State private var artistImage: PhotosPickerItem?
    @State private var artistImageData: Data?
    
    // Post fields
    @State private var postCaption = ""
    @State private var postTag = "Makeup"
    @State private var postImage: PhotosPickerItem?
    @State private var postImageData: Data?
    @State private var selectedArtistId = ""
    
    @State private var isUploading = false
    @State private var message = ""
    
    let services = ["Makeup", "Hair", "Nails", "Lashes", "Skin", "Brows", "Body"]
    let tags = ["Makeup", "Hair", "Nails", "Lashes", "Skin", "Brows", "Body"]
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Artist Section
                Section("Add New Artist") {
                    TextField("Full Name", text: $artistName)
                    TextField("Username (no @)", text: $artistUsername)
                        .textInputAutocapitalization(.never)
                    TextField("Bio", text: $artistBio)
                    TextField("City", text: $artistCity)
                    TextField("Instagram (@handle)", text: $artistInstagram)
                        .textInputAutocapitalization(.never)
                    
                    // Services picker
                    NavigationLink {
                        List(services, id: \.self) { service in
                            Button {
                                if selectedServices.contains(service) {
                                    selectedServices.remove(service)
                                } else {
                                    selectedServices.insert(service)
                                }
                            } label: {
                                HStack {
                                    Text(service)
                                    Spacer()
                                    if selectedServices.contains(service) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        .navigationTitle("Select Services")
                    } label: {
                        HStack {
                            Text("Services")
                            Spacer()
                            Text(selectedServices.joined(separator: ", "))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                    
                    // Profile image picker
                    PhotosPicker(selection: $artistImage, matching: .images) {
                        HStack {
                            Text("Profile Image")
                            Spacer()
                            if artistImageData != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .onChange(of: artistImage) { _, newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                artistImageData = data
                            }
                        }
                    }
                    
                    Button("Upload Artist") {
                        uploadArtist()
                    }
                    .disabled(artistName.isEmpty || artistUsername.isEmpty || isUploading)
                }
                
                // MARK: - Post Section
                Section("Add New Post") {
                    TextField("Artist ID", text: $selectedArtistId)
                        .textInputAutocapitalization(.never)
                    
                    Picker("Tag", selection: $postTag) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag).tag(tag)
                        }
                    }
                    
                    TextField("Caption (optional)", text: $postCaption)
                    
                    PhotosPicker(selection: $postImage, matching: .images) {
                        HStack {
                            Text("Post Image")
                            Spacer()
                            if postImageData != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .onChange(of: postImage) { _, newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                postImageData = data
                            }
                        }
                    }
                    
                    Button("Upload Post") {
                        uploadPost()
                    }
                    .disabled(selectedArtistId.isEmpty || postImageData == nil || isUploading)
                }
                
                // Status
                if !message.isEmpty {
                    Section {
                        Text(message)
                            .foregroundColor(message.contains("Error") ? .red : .green)
                    }
                }
            }
            .navigationTitle("Admin Upload")
            .disabled(isUploading)
            .overlay {
                if isUploading {
                    ProgressView("Uploading...")
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(10)
                }
            }
        }
    }
    
    private func uploadArtist() {
        isUploading = true
        message = ""
        
        let storage = Storage.storage()
        let artistId = UUID().uuidString
        
        // Upload image first if exists
        if let imageData = artistImageData {
            let imageRef = storage.reference().child("artists/\(artistId).jpg")
            imageRef.putData(imageData) { _, error in
                if let error = error {
                    message = "Error uploading image: \(error.localizedDescription)"
                    isUploading = false
                    return
                }
                
                imageRef.downloadURL { url, error in
                    if let url = url {
                        createArtist(imageURL: url.absoluteString)
                    } else {
                        createArtist(imageURL: nil)
                    }
                }
            }
        } else {
            createArtist(imageURL: nil)
        }
    }
    
    private func createArtist(imageURL: String?) {
        let artist = Artist(
            id: UUID().uuidString,
            fullName: artistName,
            username: artistUsername,
            bio: artistBio,
            profileImageURL: imageURL,
            services: Array(selectedServices),
            city: artistCity,
            instagram: artistInstagram,
            website: nil,
            phoneNumber: nil,
            claimed: false,
            claimedBy: nil,
            claimedAt: nil,
            featured: true,
            createdAt: Date()
        )
        
        feedService.uploadArtist(artist) { result in
            isUploading = false
            switch result {
            case .success(let id):
                message = "Artist uploaded! ID: \(id)"
                clearArtistFields()
            case .failure(let error):
                message = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    private func uploadPost() {
        guard let imageData = postImageData else { return }
        
        isUploading = true
        message = ""
        
        let storage = Storage.storage()
        let postId = UUID().uuidString
        let imageRef = storage.reference().child("posts/\(postId).jpg")
        
        imageRef.putData(imageData) { _, error in
            if let error = error {
                message = "Error uploading image: \(error.localizedDescription)"
                isUploading = false
                return
            }
            
            imageRef.downloadURL { url, error in
                guard let url = url else {
                    message = "Error getting download URL"
                    isUploading = false
                    return
                }
                
                // Fetch artist info
                feedService.fetchArtist(artistId: selectedArtistId) { artist in
                    let post = Post(
                        id: postId,
                        artistId: selectedArtistId,
                        artistName: artist?.fullName ?? "Unknown",
                        artistHandle: artist?.displayHandle ?? "@unknown",
                        artistProfileImageURL: artist?.profileImageURL,
                        imageURL: url.absoluteString,
                        imageHeight: CGFloat.random(in: 240...340),
                        tag: postTag,
                        caption: postCaption.isEmpty ? nil : postCaption,
                        saveCount: 0,
                        createdAt: Date()
                    )
                    
                    feedService.uploadPost(post) { result in
                        isUploading = false
                        switch result {
                        case .success(let id):
                            message = "Post uploaded! ID: \(id)"
                            clearPostFields()
                        case .failure(let error):
                            message = "Error: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
    }
    
    private func clearArtistFields() {
        artistName = ""
        artistUsername = ""
        artistBio = ""
        artistCity = ""
        artistInstagram = ""
        selectedServices = []
        artistImage = nil
        artistImageData = nil
    }
    
    private func clearPostFields() {
        postCaption = ""
        postImage = nil
        postImageData = nil
    }
}
