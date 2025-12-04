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
    @State private var showBusinessSetup = false
    
    // For saved posts collection categories
    @State private var selectedCollection: String = "Your Artists"
    //private let collections = ["Your Artists", "Nails in SJ", "Makeup Inspo", "Lashes"]
    
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
                        
                        // Business setup card (only for non-professionals)
                        if !authManager.hasBusinessProfile {
                            businessSetupCard
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
            .sheet(isPresented: $showBusinessSetup) {
                BusinessOnboardingView()
                    .environmentObject(authManager)
            }
            .onAppear {
                loadSavedPosts()
                if authManager.hasBusinessProfile {
                    // Fetch user's own posts for professionals
                    feedService.fetchUserPosts(userId: authManager.firebaseUID ?? "")
                }
                feedService.fetchPosts()
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
                        .aspectRatio(contentMode: .fill)
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
    
    // MARK: - Business Setup Card (for clients)
    private var businessSetupCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Service Provider?")
                    .font(KHOITheme.headline)
                    .foregroundColor(KHOIColors.darkText)
                Text("Create a business page to post work.")
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.mutedText)
            }
            
            Spacer()
            
            Button(action: { showBusinessSetup = true }) {
                Text("Get Started")
                    .font(KHOITheme.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(KHOIColors.darkText)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(KHOIColors.cardBackground)
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
    
    // MARK: - Posts Grid (for professionals)
    private var postsGridSection: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 2),
                GridItem(.flexible(), spacing: 2),
                GridItem(.flexible(), spacing: 2)
            ],
            spacing: 2
        ) {
            ForEach(feedService.userPosts) { post in
                postGridTile(post: post)
            }
        }
        .padding(.top, 8)
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
            
            // Collection tabs
            /*
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(collections, id: \.self) { collection in
                        Button(action: { selectedCollection = collection }) {
                            Text(collection)
                                .font(.system(size: 13, weight: selectedCollection == collection ? .medium : .regular))
                                .foregroundColor(selectedCollection == collection ? KHOIColors.darkText : KHOIColors.mutedText)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 12)
            */
            
            // Masonry grid of saved posts
            let savedPosts = feedService.posts.filter { savedPostIDs.contains($0.id) }
            
            if savedPosts.isEmpty {
                emptyStateView
            } else {
                savedMasonryGrid(posts: savedPosts)
            }
        }
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
        if savedPostIDs.contains(post.id) {
            savedPostIDs.remove(post.id)
        } else {
            savedPostIDs.insert(post.id)
        }
        saveSavedPosts()
    }
    
    private func loadSavedPosts() {
        if let array = UserDefaults.standard.array(forKey: "savedPostIDs") as? [String] {
            savedPostIDs = Set(array)
        }
    }
    
    private func saveSavedPosts() {
        UserDefaults.standard.set(Array(savedPostIDs), forKey: "savedPostIDs")
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
                
                Text(post.artistHandle.replacingOccurrences(of: "@", with: ""))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(KHOIColors.darkText)
                    .lineLimit(1)
                
                Spacer()
                
                TagBadge(tag: post.tag)
            }
            .padding(.bottom, 8)
            
            // Post image
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

#Preview {
    UserProfileView()
        .environmentObject(AuthManager())
}
