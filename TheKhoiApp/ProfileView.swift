//
//  ProfileView.swift
//  TheKhoiApp
//
//  Unified Profile View - Shows different UI for Client vs Professional
//

import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var feedService = FeedService()
    
    // UI State
    @State private var selectedTab: ProfileTab = .posts
    @State private var savedPostIDs: Set<String> = []
    @State private var showSettings = false
    @State private var showProOnboarding = false // CHANGED: Use ProOnboardingView
    
    enum ProfileTab {
        case posts
        case saved
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header with cover image and profile pic
                        profileHeader
                        
                        // User info section
                        userInfoSection
                        
                        // UPDATED: Pro application card (only for non-professionals)
                        if !authManager.hasBusinessProfile {
                            proApplicationCard
                        }
                        
                        // Tab selector
                        tabSelector
                        
                        // Content based on selected tab and user type
                        contentSection
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                        .environmentObject(authManager)
                }
            }
            .sheet(isPresented: $showProOnboarding) {
                ProOnboardingView()
                    .environmentObject(authManager)
            }
            .onAppear {
                loadSavedPosts()
                if authManager.hasBusinessProfile {
                    // Fetch user's own posts for professionals
                    feedService.fetchUserPosts(userId: authManager.firebaseUID ?? "")
                }
                feedService.fetchPosts()
                
                // ADDED: Check for pending application
                if !authManager.hasBusinessProfile {
                    authManager.checkPendingProApplication()
                }
            }
        }
    }
    
    // MARK: - Profile Header (Cover + Avatar)
    private var profileHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Cover Image
            if let coverURL = authManager.currentUser?.coverImageURL,
               let url = URL(string: coverURL), !coverURL.isEmpty {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    defaultCoverGradient
                }
                .frame(height: 180)
                .clipped()
            } else {
                defaultCoverGradient
                    .frame(height: 180)
            }
            
            // Settings button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 50)
                }
                Spacer()
            }
            
            // Profile Picture
            profilePicture
                .offset(x: 20, y: 45)
        }
        .padding(.bottom, 50)
    }
    
    private var defaultCoverGradient: some View {
        LinearGradient(
            colors: [Color(hex: "8B4D5C"), Color(hex: "C4A07C")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var profilePicture: some View {
        ZStack {
            Circle()
                .fill(KHOIColors.background)
                .frame(width: 96, height: 96)
            
            if let profileURL = authManager.currentUser?.profileImageURL,
               let url = URL(string: profileURL), !profileURL.isEmpty {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    defaultAvatar
                }
                .frame(width: 88, height: 88)
                .clipShape(Circle())
            } else {
                defaultAvatar
            }
        }
    }
    
    private var defaultAvatar: some View {
        Circle()
            .fill(Color(hex: "B5D6E8"))
            .frame(width: 88, height: 88)
    }
    
    // MARK: - User Info Section
    private var userInfoSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(authManager.currentUser?.fullName ?? "Guest User")
                    .font(KHOITheme.heading2)
                    .foregroundColor(KHOIColors.darkText)
                
                // Stats for professionals
                if authManager.hasBusinessProfile {
                    Text("\(feedService.userPosts.count) posts | \(authManager.currentUser?.location ?? "Location")")
                        .font(KHOITheme.caption)
                        .foregroundColor(KHOIColors.mutedText)
                } else {
                    Text("@\(authManager.currentUser?.username ?? "username")")
                        .font(KHOITheme.caption)
                        .foregroundColor(KHOIColors.mutedText)
                }
                
                // Bio
                if let bio = authManager.currentUser?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.mutedText)
                        .padding(.top, 4)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Mode toggle for professionals
            if authManager.hasBusinessProfile {
                ModeToggle(isBusinessMode: $authManager.isBusinessMode)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
    
    // MARK: - UPDATED Pro Application Card
    private var proApplicationCard: some View {
        VStack(spacing: 12) {
            if authManager.hasPendingProApplication {
                // Pending Application State
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Application Under Review")
                            .font(KHOITheme.headline)
                            .foregroundColor(KHOIColors.darkText)
                        Text("We'll notify you within 24-48 hours")
                            .font(KHOITheme.caption)
                            .foregroundColor(KHOIColors.mutedText)
                    }
                    Spacer()
                }
            } else {
                // Not Applied Yet
                HStack {
                    VStack(alignment: .leading) {
                        Text("Service Provider?")
                            .font(KHOITheme.headline)
                            .foregroundColor(KHOIColors.darkText)
                        Text("Apply to become a verified pro.")
                            .font(KHOITheme.caption)
                            .foregroundColor(KHOIColors.mutedText)
                    }
                    
                    Spacer()
                    
                    Button(action: { showProOnboarding = true }) {
                        Text("Verify Here")
                            .font(KHOITheme.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(KHOIColors.brandRed)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(KHOIColors.white)
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            // Posts tab (only for professionals)
            if authManager.hasBusinessProfile {
                tabButton(title: "POSTS", isSelected: selectedTab == .posts) {
                    selectedTab = .posts
                }
            }
            
            // Saved tab (for everyone)
            tabButton(
                title: "SAVED",
                isSelected: selectedTab == .saved || !authManager.hasBusinessProfile
            ) {
                selectedTab = .saved
            }
        }
        .padding(.horizontal, 16)
    }
    
    private func tabButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .tracking(1)
                    .foregroundColor(isSelected ? KHOIColors.darkText : KHOIColors.mutedText)
                
                Rectangle()
                    .fill(isSelected ? KHOIColors.darkText : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        Group {
            if authManager.hasBusinessProfile && selectedTab == .posts {
                // Professional: Show their posts grid
                postsGridSection
            } else {
                // Saved section with collections
                savedCollectionSection
            }
        }
    }
    
    // MARK: - Posts Grid (for professionals) - UPDATED TO 3x3
    private var postsGridSection: some View {
        Group {
            if feedService.userPosts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 48))
                        .foregroundColor(KHOIColors.mutedText.opacity(0.5))
                    
                    Text("No posts yet")
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.mutedText)
                    
                    Text("Share your work to build your portfolio")
                        .font(KHOITheme.caption)
                        .foregroundColor(KHOIColors.mutedText.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 80)
            } else {
                InstagramGrid(posts: feedService.userPosts)
                    .padding(.top, 4)
            }
        }
    }
    
    private func postGridTile(post: Post) -> some View {
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
    }
    
    // MARK: - Saved Collection Section
    private var savedCollectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if feedService.savedPosts.isEmpty {
                emptyStateView
            } else {
                savedMasonryGrid(posts: feedService.savedPosts)
            }
        }
        .padding(.top, 12)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundColor(KHOIColors.mutedText.opacity(0.5))
            
            Text("No saved posts yet")
                .font(KHOITheme.body)
                .foregroundColor(KHOIColors.mutedText)
            
            Text("Save looks you love from Discover")
                .font(KHOITheme.caption)
                .foregroundColor(KHOIColors.mutedText.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private func savedMasonryGrid(posts: [Post]) -> some View {
        let columns = splitPosts(posts)
        
        return HStack(alignment: .top, spacing: 12) {
            LazyVStack(spacing: 12) {
                ForEach(columns.left) { post in
                    SavedPostCard(
                        post: post,
                        onSaveTap: { toggleSave(post: post) }
                    )
                }
            }
            
            LazyVStack(spacing: 12) {
                ForEach(columns.right) { post in
                    SavedPostCard(
                        post: post,
                        onSaveTap: { toggleSave(post: post) }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
    }
    
    // MARK: - Helpers
    
    private func splitPosts(_ posts: [Post]) -> (left: [Post], right: [Post]) {
        var left: [Post] = []
        var right: [Post] = []
        
        for (index, post) in posts.enumerated() {
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
        
        // Update Firestore
        feedService.toggleSavePost(postId: post.id, userId: userId, isSaving: !wasAlreadySaved)
    }
    
    private func loadSavedPosts() {
        guard let userId = authManager.firebaseUID else { return }
        feedService.fetchUserSavedPosts(userId: userId) { postIds in
            self.savedPostIDs = postIds
        }
    }
}

// MARK: - Saved Post Card (for collection view)
struct SavedPostCard: View {
    let post: Post
    let onSaveTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Artist info row
            HStack(spacing: 8) {
                if let profileURL = post.artistProfileImageURL, let url = URL(string: profileURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(KHOIColors.chipBackground)
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(KHOIColors.chipBackground)
                        .frame(width: 24, height: 24)
                }
                
                NavigationLink(destination: ArtistProfileLoader(artistId: post.artistId)) {
                    Text(post.artistHandle.replacingOccurrences(of: "@", with: ""))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(KHOIColors.darkText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                TagBadge(tag: post.tag)
            }
            .padding(.bottom, 8)
            
            // Post image - navigate to PostDetailView
            NavigationLink(destination: PostDetailView(post: post)) {
                AsyncImage(url: URL(string: post.imageURL)) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(KHOIColors.chipBackground)
                            .aspectRatio(0.8, contentMode: .fit)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        Rectangle()
                            .fill(KHOIColors.chipBackground)
                            .aspectRatio(0.8, contentMode: .fit)
                    @unknown default:
                        Rectangle()
                            .fill(KHOIColors.chipBackground)
                    }
                }
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            
            // Save count
            HStack(spacing: 6) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 12))
                    .foregroundColor(KHOIColors.accentBrown)
                
                Text(formatSaveCount(post.saveCount))
                    .font(.system(size: 11))
                    .foregroundColor(KHOIColors.mutedText)
            }
            .padding(.top, 8)
        }
    }
    
    private func formatSaveCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk saved", Double(count) / 1000.0)
        }
        return "\(count) saved"
    }
}

// MARK: - Instagram-Style 3x3 Grid Component
struct InstagramGrid: View {
    let posts: [Post]
    let columns = 3
    let spacing: CGFloat = 1
    
    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
            spacing: spacing
        ) {
            ForEach(posts) { post in
                NavigationLink(destination: PostDetailView(post: post)) {
                    GridPostTile(post: post)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct GridPostTile: View {
    let post: Post
    
    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: URL(string: post.imageURL)) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(KHOIColors.chipBackground)
                        .overlay(
                            ProgressView()
                                .tint(KHOIColors.mutedText)
                        )
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .clipped()
                case .failure:
                    Rectangle()
                        .fill(KHOIColors.chipBackground)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(KHOIColors.mutedText)
                                .font(.system(size: 24))
                        )
                @unknown default:
                    Rectangle()
                        .fill(KHOIColors.chipBackground)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    UserProfileView()
        .environmentObject(AuthManager())
}
