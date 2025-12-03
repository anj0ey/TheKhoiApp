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

    // In the future, this will come from FeedService / backend
    private let categories = ["All", "Hair", "Nails", "Makeup", "Brows", "Skin"]
    @StateObject private var feedService = FeedService()

    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: KHOITheme.spacing_md) {

                        // MARK: - Title + Mode Toggle
                        VStack(alignment: .leading, spacing: KHOITheme.spacing_sm) {
                            HStack {
                                Text("Discover")
                                    .font(KHOITheme.heading2)
                                    .foregroundColor(KHOIColors.darkText)
                                Spacer()
                            }

                            HStack(spacing: 8) {
                                modePill(title: "Client", isSelected: mode == .client) {
                                    mode = .client
                                }
                                modePill(title: "Business", isSelected: mode == .business) {
                                    mode = .business
                                }
                                Spacer()
                            }
                        }
                        .padding(.horizontal, KHOITheme.spacing_md)
                        .padding(.top, KHOITheme.spacing_md)

                        // MARK: - Search Bar
                        RoundedRectangle(cornerRadius: KHOITheme.radius_lg)
                            .fill(KHOIColors.cardBackground)
                            .overlay(
                                HStack(spacing: KHOITheme.spacing_sm) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(KHOIColors.mutedText)
                                    TextField("Search providers, styles…", text: $searchText)
                                        .font(KHOITheme.body)
                                        .foregroundColor(KHOIColors.darkText)
                                        .autocorrectionDisabled()
                                    Spacer()
                                }
                                .padding(.horizontal, KHOITheme.spacing_md)
                                .padding(.vertical, KHOITheme.spacing_sm)
                            )
                            .frame(height: 48)
                            .padding(.horizontal, KHOITheme.spacing_md)

                        // MARK: - Category Chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: KHOITheme.spacing_sm) {
                                ForEach(categories, id: \.self) { category in
                                    Button {
                                        selectedCategory = category
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

                        // MARK: - Grid Label
                        Text(mode == .client ? "For you" : "Featured artists")
                            .font(KHOITheme.bodyBold)
                            .foregroundColor(KHOIColors.darkText)
                            .padding(.horizontal, KHOITheme.spacing_md)

                        // MARK: - Post Grid
                        let columns = [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ]

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            // Loop through the NEW filteredPosts
                            ForEach(filteredPosts) { post in
                                discoverTile(post: post)
                            }
                        }
                        .padding(.horizontal, KHOITheme.spacing_md)
                        .padding(.bottom, 40)
                    }
                }
            }
            .onAppear {
                        feedService.fetchPosts(category: selectedCategory == "All" ? nil : selectedCategory)
                    }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Derived Posts

    private var filteredPosts: [Post] {
        // 1. Start with the real posts from Firebase
        let posts = feedService.posts
        
        // 2. Filter by Search Text (if user typed anything)
        if searchText.isEmpty {
            return posts
        } else {
            return posts.filter { post in
                // Search in Caption OR Artist Name
                let captionMatch = post.caption?.localizedCaseInsensitiveContains(searchText) ?? false
                let artistMatch = post.artistName.localizedCaseInsensitiveContains(searchText)
                return captionMatch || artistMatch
            }
        }
    }
    // MARK: - Subviews

    private func modePill(title: String,
                          isSelected: Bool,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(KHOITheme.caption)
                .padding(.horizontal, KHOITheme.spacing_md)
                .padding(.vertical, 8)
                .background(
                    isSelected
                    ? KHOIColors.accent.opacity(0.16)
                    : KHOIColors.cardBackground
                )
                .foregroundColor(
                    isSelected
                    ? KHOIColors.accent
                    : KHOIColors.darkText
                )
                .cornerRadius(999)
        }
    }

    private func discoverTile(post: Post) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Use AsyncImage for real URLs
            AsyncImage(url: URL(string: post.imageURL)) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.gray.opacity(0.1) // Placeholder while loading
                }
            }
            .frame(height: 200)
            .cornerRadius(14)
            .clipped()

            Text(post.caption ?? "")
                .font(KHOITheme.caption)
                .lineLimit(1)
                .foregroundColor(KHOIColors.darkText)

            Text(post.artistName)
                .font(KHOITheme.caption)
                .foregroundColor(KHOIColors.mutedText)
        }
    }
}

#Preview {
    DiscoverView()
}
