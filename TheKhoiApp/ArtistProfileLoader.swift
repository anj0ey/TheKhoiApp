//
//  ArtistProfileLoader.swift
//  TheKhoiApp
//
//  Created by Anjo on 12/2/25.
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
                .onAppear { fetchArtist() }
            } else if let artist = artist {
                // Success: Pass the data to your existing view
                ArtistProfileView(artist: artist)
            } else {
                // Failure State
                VStack(spacing: 12) {
                    Image(systemName: "person.slash")
                        .font(.largeTitle)
                        .foregroundColor(KHOIColors.mutedText)
                    Text(errorMessage ?? "Artist not found")
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.mutedText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(KHOIColors.background)
            }
        }
    }
    
    private func fetchArtist() {
        let db = Firestore.firestore()
        db.collection("artists").document(artistId).getDocument { snapshot, error in
            isLoading = false
            
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            
            guard let document = snapshot, document.exists else {
                errorMessage = "Artist profile not found."
                return
            }
            
            // Decode directly using Codable
            do {
                self.artist = try document.data(as: Artist.self)
            } catch {
                print("Error decoding artist: \(error)")
                errorMessage = "Failed to load artist data."
            }
        }
    }
}
