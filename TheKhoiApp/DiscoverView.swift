//
//  DiscoverView.swift
//  TheKhoiApp
//
//  Updated with working search functionality
//

import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var authManager: AuthManager
    
    // State
    @State private var searchText: String = ""
    @State private var isSearchFocused: Bool = false
    @State private var selectedCategory: String = "All"
    @StateObject private var feedService = FeedService()
    @StateObject private var searchService = SearchService()
    @State private var savedPostIDs: Set<String> = []
    @State private var showLoginPrompt: Bool = false

    private let categories = ["All", "Skin", "Nails", "Makeup", "Lash", "Hair", "Brows", "Body"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: KHOITheme.spacing_md) {
                        // 1. Search Bar
                        searchBarSection
                        
                        // Show search results OR normal feed
                        if !searchText.isEmpty {
                            searchResultsSection
                        } else {
                            // 2. Category Filter Pills
                            categoryPillsSection
                            
                            // 3. DISCOVER Header + Toggle
                            discoverHeaderSection
                            
                            // 4. MASONRY GRID
                            masonryFeedSection
                        }
                    }
                    .padding(.top, KHOITheme.spacing_sm)
                }
            }
            .onAppear {
                feedService.fetchPosts(category: selectedCategory == "All" ? nil : selectedCategory)
                loadSavedPosts()
            }
            .onChange(of: searchText) { newValue in
                searchService.search(query: newValue)
            }
            .sheet(isPresented: $showLoginPrompt) {
                SaveLoginPromptSheet()
                    .environmentObject(authManager)
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBarSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(KHOIColors.mutedText)
                .font(.system(size: 18))
            
            TextField("Find your beauty...", text: $searchText)
                .font(KHOITheme.body)
                .foregroundColor(KHOIColors.darkText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    searchService.clearResults()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(KHOIColors.mutedText)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, KHOITheme.spacing_lg)
        .padding(.vertical, 14)
        .background(KHOIColors.cardBackground)
        .cornerRadius(KHOITheme.cornerRadius_lg)
        .padding(.horizontal, KHOITheme.spacing_md)
    }
    
    // MARK: - Search Results
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: KHOITheme.spacing_lg) {
            
            // Loading indicator
            if searchService.isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(KHOIColors.accentBrown)
                    Spacer()
                }
                .padding(.top, 20)
            }
            
            // Users Section
            if !searchService.userResults.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("USERS")
                        .font(KHOITheme.captionUppercase)
                        .foregroundColor(KHOIColors.mutedText)
                        .padding(.horizontal, KHOITheme.spacing_md)
                    
                    ForEach(searchService.userResults) { user in
                        NavigationLink(destination: ArtistProfileLoader(artistId: user.id)) {
                            UserSearchRow(user: user)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Posts Section
            if !searchService.postResults.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("POSTS")
                        .font(KHOITheme.captionUppercase)
                        .foregroundColor(KHOIColors.mutedText)
                        .padding(.horizontal, KHOITheme.spacing_md)
                    
                    // Grid of post results - navigate to Artist Profile
                    // (PostSearchResult doesn't have full Post data needed for PostDetailView)
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ],
                        spacing: 8
                    ) {
                        ForEach(searchService.postResults) { post in
                            NavigationLink(destination: ArtistProfileLoader(artistId: post.artistId)) {
                                PostSearchTile(post: post)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, KHOITheme.spacing_md)
                }
            }
            
            // No results
            if !searchService.isSearching && searchService.userResults.isEmpty && searchService.postResults.isEmpty && !searchText.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(KHOIColors.mutedText.opacity(0.5))
                    
                    Text("No results for \"\(searchText)\"")
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.mutedText)
                    
                    Text("Try searching for users or beauty services")
                        .font(KHOITheme.caption)
                        .foregroundColor(KHOIColors.mutedText.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            }
            
            Spacer(minLength: 100)
        }
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
            LazyVStack(spacing: 12) {
                ForEach(columns.left) { post in
                    DiscoverPostCard(
                        post: post,
                        isSaved: savedPostIDs.contains(post.id),
                        onSaveTap: { toggleSave(post: post) }
                    )
                }
            }
            
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
        .padding(.bottom, 100)
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
        // Check if user is logged in
        guard authManager.isLoggedIn, let userId = authManager.firebaseUID else {
            // Show login prompt for guests
            showLoginPrompt = true
            return
        }
        
        let wasAlreadySaved = savedPostIDs.contains(post.id)
        
        if wasAlreadySaved {
            savedPostIDs.remove(post.id)
        } else {
            savedPostIDs.insert(post.id)
        }
        
        feedService.toggleSavePost(postId: post.id, userId: userId, isSaving: !wasAlreadySaved)
    }
    
    private func loadSavedPosts() {
        guard authManager.isLoggedIn, let userId = authManager.firebaseUID else { return }
        feedService.fetchUserSavedPosts(userId: userId) { postIds in
            self.savedPostIDs = postIds
        }
    }
}

// MARK: - User Search Row
struct UserSearchRow: View {
    let user: UserSearchResult
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile image
            if let urlString = user.profileImageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(KHOIColors.chipBackground)
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(KHOIColors.chipBackground)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(KHOIColors.mutedText)
                    )
            }
            
            // Name and username
            VStack(alignment: .leading, spacing: 2) {
                Text(user.fullName)
                    .font(KHOITheme.bodyBold)
                    .foregroundColor(KHOIColors.darkText)
                
                Text("@\(user.username)")
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.mutedText)
            }
            
            Spacer()
            
            // Artist badge
            if user.isArtist {
                Text("PRO")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(KHOIColors.accentBrown)
                    .cornerRadius(8)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(KHOIColors.mutedText)
        }
        .padding(.horizontal, KHOITheme.spacing_md)
        .padding(.vertical, 8)
        .background(KHOIColors.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal, KHOITheme.spacing_md)
    }
}

// MARK: - Post Search Tile
struct PostSearchTile: View {
    let post: PostSearchResult
    
    var body: some View {
        AsyncImage(url: URL(string: post.imageURL)) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(KHOIColors.chipBackground)
                    .aspectRatio(1, contentMode: .fit)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
            case .failure:
                Rectangle()
                    .fill(KHOIColors.chipBackground)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(KHOIColors.mutedText)
                    )
            @unknown default:
                Rectangle()
                    .fill(KHOIColors.chipBackground)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .cornerRadius(8)
    }
}

// MARK: - Mode Toggle (CLIENT / PRO)
struct ModeToggle: View {
    @Binding var isBusinessMode: Bool
    
    var body: some View {
        HStack(spacing: 0) {
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
            artistInfoRow
            postImage
            saveRow
        }
    }
    
    private var artistInfoRow: some View {
        HStack(spacing: 8) {
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
            
            NavigationLink(destination: ArtistProfileLoader(artistId: post.artistId)) {
                Text(post.artistHandle.replacingOccurrences(of: "@", with: ""))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(KHOIColors.darkText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            TagBadge(tag: post.tag)
        }
        .padding(.bottom, 8)
    }
    
    private var postImage: some View {
        // Navigate to PostDetailView when tapping the image
        NavigationLink(destination: PostDetailView(post: post)) {
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
        case "makeup": return Color(hex: "E8B4B8")
        case "hair": return Color(hex: "B8A9C9")
        case "nails", "nail": return Color(hex: "A8D4A8")
        case "lashes", "lash": return Color(hex: "A8C8D4")
        case "skin": return Color(hex: "F5CBA7")
        case "brows": return Color(hex: "D4B896")
        case "body": return Color(hex: "C9B99A")
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

// MARK: - Save Login Prompt Sheet
struct SaveLoginPromptSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 60))
                        .foregroundColor(KHOIColors.accentBrown)
                    
                    Text("Save Your Favorites")
                        .font(KHOITheme.title)
                        .foregroundColor(KHOIColors.darkText)
                    
                    Text("Sign in to save looks you love and build your personal collection.")
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.mutedText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    VStack(spacing: 12) {
                        Button(action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                authManager.showOnboarding = true
                            }
                        }) {
                            Text("Sign In / Create Account")
                                .font(KHOITheme.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(KHOIColors.accentBrown)
                                .cornerRadius(12)
                        }
                        
                        Button(action: { dismiss() }) {
                            Text("Maybe Later")
                                .font(KHOITheme.body)
                                .foregroundColor(KHOIColors.mutedText)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(KHOIColors.darkText)
                            .padding(8)
                            .background(KHOIColors.chipBackground)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
