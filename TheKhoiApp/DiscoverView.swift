//
//  DiscoverView.swift
//  TheKhoiApp
//
//  Created by Paige McNamara-Pittler on 12/2/25.
//

import SwiftUI

struct DiscoverView: View {
    // MARK: - State
    enum DiscoverMode {
        case client
        case business
    }

    @State private var mode: DiscoverMode = .client
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "All"
    @StateObject private var feedService = FeedService()

    private let categories = ["All", "Hair", "Nails", "Makeup", "Brows", "Skin"]
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: KHOITheme.spacing_md) {

                        // 1. Header & Mode Switch
                        headerSection

                        // 2. Search Bar
                        searchBar

                        // 3. Category Pills
                        categoryList

                        // 4. MASONRY FEED (The Pinterest Layout)
                        HStack(alignment: .top, spacing: 16) {
                            // Left Column (Even Indices)
                            LazyVStack(spacing: 16) {
                                ForEach(splitPosts().left) { post in
                                    discoverTile(post: post)
                                }
                            }
                            
                            // Right Column (Odd Indices)
                            LazyVStack(spacing: 16) {
                                ForEach(splitPosts().right) { post in
                                    discoverTile(post: post)
                                }
                            }
                        }
                        .padding(KHOITheme.spacing_md)
                    }
                }
            }
            .onAppear {
                feedService.fetchPosts(category: selectedCategory)
            }
        }
    }

    // MARK: - Data Helper for Masonry Layout
    private func splitPosts() -> (left: [Post], right: [Post]) {
        var left: [Post] = []
        var right: [Post] = []
        
        for (index, post) in feedService.posts.enumerated() {
            if index % 2 == 0 {
                left.append(post)
            } else {
                right.append(post)
            }
        }
        return (left, right)
    }

    // MARK: - Subviews (Extracted for cleanliness)
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: KHOITheme.spacing_sm) {
            HStack {
                Text("Discover")
                    .font(KHOITheme.heading2)
                    .foregroundColor(KHOIColors.darkText)
                Spacer()
            }

            HStack(spacing: 8) {
                modePill(title: "Client", isSelected: mode == .client) { mode = .client }
                modePill(title: "Business", isSelected: mode == .business) { mode = .business }
            }
        }
        .padding(.horizontal, KHOITheme.spacing_md)
        .padding(.top, KHOITheme.spacing_md)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(KHOIColors.mutedText)
            TextField("Search artists, styles...", text: $searchText)
        }
        .padding()
        .background(KHOIColors.cardBackground)
        .cornerRadius(KHOITheme.cornerRadius_md)
        .padding(.horizontal, KHOITheme.spacing_md)
    }
    
    private var categoryList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    categoryPill(
                        title: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                        feedService.fetchPosts(category: category)
                    }
                }
            }
            .padding(.horizontal, KHOITheme.spacing_md)
        }
    }

    // MARK: - Buttons
    private func modePill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(KHOITheme.caption.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? KHOIColors.darkText : Color.clear)
                .foregroundColor(isSelected ? .white : KHOIColors.mutedText)
                .cornerRadius(999)
                .overlay(
                    RoundedRectangle(cornerRadius: 999)
                        .stroke(isSelected ? Color.clear : KHOIColors.mutedText.opacity(0.3), lineWidth: 1)
                )
        }
    }

    private func categoryPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(KHOITheme.caption)
                .padding(.horizontal, KHOITheme.spacing_md)
                .padding(.vertical, 8)
                .background(isSelected ? KHOIColors.accentBrown.opacity(0.16) : KHOIColors.cardBackground)
                .foregroundColor(isSelected ? KHOIColors.accentBrown : KHOIColors.darkText)
                .cornerRadius(999)
        }
    }

    // MARK: - MASONRY TILE (The Fix)
    private func discoverTile(post: Post) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // 1. IMAGE AREA
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: post.imageURL)) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFit() // 👈 THIS IS KEY: Keeps natural aspect ratio (Pinterest style)
                    } else {
                        Rectangle()
                            .fill(KHOIColors.cardBackground)
                            .frame(height: 200) // Placeholder height only
                            .overlay(ProgressView())
                    }
                }
                .cornerRadius(12)
                .clipped()
                
                // Save Button
                Button(action: {
                    print("Saved post: \(post.id)")
                }) {
                    Circle()
                        .fill(KHOIColors.cardBackground.opacity(0.9))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "heart")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(KHOIColors.accentBrown)
                        )
                        .padding(8)
                }
            }

            // 2. CAPTION & ARTIST
            VStack(alignment: .leading, spacing: 4) {
                if let caption = post.caption, !caption.isEmpty {
                    Text(caption)
                        .font(KHOITheme.caption)
                        .lineLimit(2)
                        .foregroundColor(KHOIColors.darkText)
                }

                NavigationLink(destination: ArtistProfileLoader(artistId: post.artistId)) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(KHOIColors.mutedText.opacity(0.2))
                            .frame(width: 16, height: 16)
                            .overlay(Image(systemName: "person.fill").font(.system(size: 8)).foregroundColor(KHOIColors.mutedText))
                        
                        Text(post.artistName)
                            .font(KHOITheme.caption)
                            .bold()
                            .foregroundColor(KHOIColors.mutedText)
                    }
                }
            }
        }
        .padding(.bottom, 8) // Spacing between items in the column
    }
}

#Preview {
    DiscoverView()
}
