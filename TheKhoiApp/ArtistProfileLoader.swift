//
//  ArtistProfileLoader.swift
//  TheKhoiApp
//

import SwiftUI
import FirebaseFirestore

struct ArtistProfileLoader: View {
    let artistId: String
    @State private var artist: Artist?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if isLoading {
                ZStack {
                    KHOIColors.background.ignoresSafeArea()
                    ProgressView()
                        .tint(KHOIColors.accentBrown)
                }
                .onAppear { fetchProfile() }
            } else if let artist = artist {
                ArtistProfileView(artist: artist)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "person.slash")
                        .font(.largeTitle)
                        .foregroundColor(KHOIColors.mutedText)
                    Text(errorMessage ?? "Profile not found")
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.mutedText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(KHOIColors.background)
            }
        }
    }
    
    private func fetchProfile() {
        let db = Firestore.firestore()
        
        // First, try to fetch from artists collection
        db.collection("artists").document(artistId).getDocument { snapshot, error in
            if let document = snapshot, document.exists {
                // Found in artists collection
                do {
                    self.artist = try document.data(as: Artist.self)
                    self.isLoading = false
                } catch {
                    print("Error decoding artist: \(error)")
                    // Try users collection as fallback
                    self.fetchFromUsers(db: db)
                }
            } else {
                // Not found in artists, try users collection
                self.fetchFromUsers(db: db)
            }
        }
    }
    
    private func fetchFromUsers(db: Firestore) {
        db.collection("users").document(artistId).getDocument { snapshot, error in
            isLoading = false
            
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            
            guard let document = snapshot, document.exists, let data = document.data() else {
                errorMessage = "Profile not found."
                return
            }
            
            // Convert user data to Artist object for display
            let fullName = data["fullName"] as? String ?? "Unknown"
            let username = data["username"] as? String ?? "user"
            let bio = data["bio"] as? String ?? ""
            let profileImageURL = data["profileImageURL"] as? String
            let coverImageURL = data["coverImageURL"] as? String
            let location = data["location"] as? String ?? ""
            
            self.artist = Artist(
                id: document.documentID,
                fullName: fullName,
                username: username,
                bio: bio,
                profileImageURL: profileImageURL,
                coverImageURL: coverImageURL,
                services: [],
                city: location,
                instagram: nil,
                website: nil,
                phoneNumber: nil,
                claimed: false,
                claimedBy: nil,
                claimedAt: nil,
                featured: false,
                referralCount: 0,
                reviewCount: 0,
                rating: nil,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
    }
}
