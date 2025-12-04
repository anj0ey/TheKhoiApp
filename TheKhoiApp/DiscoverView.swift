//
//  DiscoverView.swift
//  TheKhoiApp
//
//  Updated to match reference UI design
//

import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var authManager: AuthManager
    
    // State
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "All"
    @StateObject private var feedService = FeedService()
    @State private var savedPostIDs: Set<String> = []

    private let categories = ["All", "Skin", "Nails", "Makeup", "Lashes", "Hair", "Brows", "Body"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: KHOITheme.spacing_md) {
                        
                        // 1. Search Bar
                        searchBarSection
                        
                        // 2. Category Filter Pills
                        categoryPillsSection
                        
                        // 3. DISCOVER Header + Toggle
                        discoverHeaderSection
                        
                        // 4. MASONRY GRID
                        masonryFeedSection
                    }
                    .padding(.top, KHOITheme.spacing_sm)
                }
            }
            .onAppear {
                feedService.fetchPosts(category: selectedCategory == "All" ? nil : selectedCategory)
                loadSavedPosts()
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBarSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(KHOIColors.mutedText)
                .font(.system(size: 18))
            
            TextField("Find your beauty", text: $searchText)
                .font(KHOITheme.body)
                .foregroundColor(KHOIColors.darkText)
        }
        .padding(.horizontal, KHOITheme.spacing_lg)
        .padding(.vertical, 14)
        .background(KHOIColors.cardBackground)
        .cornerRadius(KHOITheme.cornerRadius_lg)
        .padding(.horizontal, KHOITheme.spacing_md)
    }
    
    // MARK: - Category Pills
    private var categoryPillsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories, id: \.self) { category in
                    CategoryPill(
                        title: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                        feedService.fetchPosts(category: category == "All" ? nil : category)
                    }
                }
            }
            .padding(.horizontal, KHOITheme.spacing_md)
        }
    }
    
    // MARK: - DISCOVER Header + Toggle
    private var discoverHeaderSection: some View {
        HStack {
            // DISCOVER label with globe
            HStack(spacing: 8) {
                Text("DISCOVER")
                    .font(KHOITheme.headline)
                    .tracking(2)
                    .foregroundColor(KHOIColors.mutedText)
                
                Image(systemName: "globe")
                    .font(.system(size: 16))
                    .foregroundColor(KHOIColors.mutedText)
            }
            
            Spacer()
            
            // CLIENT / PRO Toggle - Only show if user has business profile
            if authManager.hasBusinessProfile {
                ModeToggle(isBusinessMode: $authManager.isBusinessMode)
            }
        }
        .padding(.horizontal, KHOITheme.spacing_md)
        .padding(.top, KHOITheme.spacing_sm)
    }
    
    // MARK: - Masonry Feed
    private var masonryFeedSection: some View {
        let columns = splitPosts()
        
        return HStack(alignment: .top, spacing: 12) {
            // Left Column
            LazyVStack(spacing: 12) {
                ForEach(columns.left) { post in
                    DiscoverPostCard(
                        post: post,
                        isSaved: savedPostIDs.contains(post.id),
                        onSaveTap: { toggleSave(post: post) }
                    )
                }
            }
            
            // Right Column
            LazyVStack(spacing: 12) {
                ForEach(columns.right) { post in
                    DiscoverPostCard(
                        post: post,
                        isSaved: savedPostIDs.contains(post.id),
                        onSaveTap: { toggleSave(post: post) }
                    )
                }
            }
        }
        .padding(.horizontal, KHOITheme.spacing_md)
        .padding(.bottom, 100) // Space for tab bar
    }
    
    // MARK: - Helpers
    
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
    
    private func toggleSave(post: Post) {
        guard let userId = authManager.firebaseUID else { return }
        
        let wasAlreadySaved = savedPostIDs.contains(post.id)
        
        if wasAlreadySaved {
            savedPostIDs.remove(post.id)
        } else {
            savedPostIDs.insert(post.id)
        }
        
        // Update Firestore: user's saved posts AND post's saveCount
        feedService.toggleSavePost(postId: post.id, userId: userId, isSaving: !wasAlreadySaved)
    }
    
    private func loadSavedPosts() {
        guard let userId = authManager.firebaseUID else { return }
        feedService.fetchUserSavedPosts(userId: userId) { postIds in
            self.savedPostIDs = postIds
        }
    }
    
}

// MARK: - Mode Toggle (CLIENT / PRO)
struct ModeToggle: View {
    @Binding var isBusinessMode: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // CLIENT
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isBusinessMode = false
                }
            }) {
                Text("CLIENT")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(!isBusinessMode ? KHOIColors.darkText : Color.white.opacity(0.5))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(!isBusinessMode ? Color.white : Color.clear)
                    )
            }
            
            // PRO
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isBusinessMode = true
                }
            }) {
                Text("PRO")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(isBusinessMode ? KHOIColors.darkText : Color.white.opacity(0.5))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(isBusinessMode ? Color.white : Color.clear)
                    )
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(KHOIColors.brandRed)
        )
    }
}

// MARK: - Category Pill
struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : KHOIColors.darkText)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? KHOIColors.darkText : KHOIColors.cardBackground)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : KHOIColors.divider, lineWidth: 1)
                )
        }
    }
}

// MARK: - Discover Post Card (Masonry Tile)
struct DiscoverPostCard: View {
    let post: Post
    let isSaved: Bool
    let onSaveTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. Artist Info Row (Profile pic + Username + Tag)
            artistInfoRow
            
            // 2. Post Image
            postImage
            
            // 3. Save Count Row
            saveRow
        }
    }
    
    // MARK: - Artist Info Row
    private var artistInfoRow: some View {
        HStack(spacing: 8) {
            // Profile Picture
            if let profileURL = post.artistProfileImageURL, let url = URL(string: profileURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(KHOIColors.chipBackground)
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(KHOIColors.chipBackground)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 12))
                            .foregroundColor(KHOIColors.mutedText)
                    )
            }
            
            // Username
            NavigationLink(destination: ArtistProfileLoader(artistId: post.artistId)) {
                Text(post.artistHandle.replacingOccurrences(of: "@", with: ""))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(KHOIColors.darkText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Tag Badge
            TagBadge(tag: post.tag)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Post Image
    private var postImage: some View {
        NavigationLink(destination: ArtistProfileLoader(artistId: post.artistId)) {
            AsyncImage(url: URL(string: post.imageURL)) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(KHOIColors.chipBackground)
                        .overlay(ProgressView())
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .failure:
                    Rectangle()
                        .fill(KHOIColors.chipBackground)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(KHOIColors.mutedText)
                        )
                @unknown default:
                    Rectangle()
                        .fill(KHOIColors.chipBackground)
                }
            }
            .cornerRadius(12)
            .clipped()
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Save Row
    private var saveRow: some View {
        Button(action: onSaveTap) {
            HStack(spacing: 6) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 14))
                    .foregroundColor(isSaved ? KHOIColors.accentBrown : KHOIColors.mutedText)
                
                Text(formatSaveCount(post.saveCount))
                    .font(.system(size: 12))
                    .foregroundColor(KHOIColors.mutedText)
            }
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helpers
    private func formatSaveCount(_ count: Int) -> String {
        if count >= 1000 {
            let k = Double(count) / 1000.0
            return String(format: "%.1fk saved", k)
        }
        return "\(count) saved"
    }
}

// MARK: - Tag Badge
struct TagBadge: View {
    let tag: String
    
    var tagColor: Color {
        switch tag.lowercased() {
        case "makeup": return Color(hex: "E8B4B8")  // Pink
        case "hair": return Color(hex: "B8A9C9")    // Purple
        case "nails", "nail": return Color(hex: "A8D4A8")  // Green
        case "lashes", "lash": return Color(hex: "A8C8D4") // Blue
        case "skin": return Color(hex: "F5CBA7")    // Orange
        case "brows": return Color(hex: "D4B896")   // Tan
        case "body": return Color(hex: "C9B99A")    // Brown
        default: return KHOIColors.chipBackground
        }
    }
    
    var body: some View {
        Text(tag.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(0.5)
            .foregroundColor(KHOIColors.darkText)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tagColor)
            .cornerRadius(12)
    }
}

#Preview {
    DiscoverView()
        .environmentObject(AuthManager())
}
