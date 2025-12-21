//
//  ArtistProfileView.swift
//  TheKhoiApp
//
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Artist Profile View
struct ArtistProfileView: View {
    let artist: Artist
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    // UI State
    @State private var selectedTab: String = "Posts"
    @State private var showBookingSheet = false
    @State private var isSaved = false
    @State private var isBioExpanded = false
    
    // Chat State
    @StateObject private var chatService = ChatService()
    @StateObject private var feedService = FeedService()
    @State private var showChat = false
    @State private var activeConversation: Conversation?
    @State private var isCreatingChat = false
    
    // Referral State
    @State private var showReferralSheet = false
    
    // Friend State
    @StateObject private var friendsService = FriendsService()
    @State private var isFriend = false
    @State private var isAddingFriend = false
    
    // Saved posts for non-pro users
    @State private var savedPosts: [Post] = []
    @State private var isLoadingSaved = false
    
    // Review State
    @State private var showReviewLimitPopup = false
    
    // Check if this is the current user's own profile
    private var isOwnProfile: Bool {
        authManager.firebaseUID == artist.id
    }
    
    // Check if this is a professional (has services or is verified)
    private var isProfessional: Bool {
        artist.hasDetailedServices || artist.verified || artist.claimed
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            KHOIColors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // 1. Header (Cover + Avatar)
                    headerSection
                    
                    // 2. Info (Name, Bio, Stats) + Add Friend button for non-pros
                    infoSection
                    
                    // 3. Content based on profile type
                    if isProfessional {
                        // Professional: Tabs (Posts / Services / Reviews)
                        tabSection
                        
                        if selectedTab == "Posts" {
                            postsGrid
                        } else if selectedTab == "Services" {
                            servicesList
                        } else {
                            ReviewsListView(
                                artist: artist,
                                showReviewLimitPopup: $showReviewLimitPopup
                            )
                            .environmentObject(authManager)
                        }
                    } else {
                        // Non-professional: Show saved posts
                        nonProSavedSection
                    }
                    
                    // Spacer for floating buttons
                    Color.clear.frame(height: 120)
                }
            }
            
            // Floating buttons (Message + Book for pros)
            if !isOwnProfile {
                floatingButtonsSection
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Referral button (paper airplane) - only for professionals
                if isProfessional && !isOwnProfile {
                    Button(action: { showReferralSheet = true }) {
                        Image(systemName: "paperplane")
                            .font(.system(size: 18))
                            .foregroundColor(KHOIColors.darkText)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showBookingSheet) {
            BookingFlowView(artist: artist, isPresented: $showBookingSheet)
        }
        .sheet(isPresented: $showReferralSheet) {
            ReferFriendView(artist: artist)
                .environmentObject(authManager)
        }
        .navigationDestination(isPresented: $showChat) {
            if let conversation = activeConversation,
               let currentUserId = authManager.firebaseUID {
                ChatDetailView(
                    conversation: conversation,
                    currentUserId: currentUserId,
                    chatService: chatService
                )
            }
        }
        .overlay {
            if showReviewLimitPopup {
                ReviewLimitPopup(
                    isPresented: $showReviewLimitPopup,
                    onBookAppointment: {
                        showReviewLimitPopup = false
                        showBookingSheet = true
                    }
                )
            }
        }
        .onAppear {
            checkFriendStatus()
            if !isProfessional {
                loadSavedPosts()
            }
        }
    }
    
    // MARK: - Floating Buttons Section
    private var floatingButtonsSection: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                // Message Button
                Button(action: startChat) {
                    HStack(spacing: 8) {
                        if isCreatingChat {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "message.fill")
                                .font(.system(size: 16))
                        }
                        Text("Message")
                            .font(KHOITheme.bodyBold)
                    }
                    .foregroundColor(KHOIColors.darkText)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(KHOIColors.cardBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(KHOIColors.divider, lineWidth: 1)
                    )
                }
                .disabled(isCreatingChat)
                
                // Book Button - only for professionals with services
                if isProfessional && artist.hasDetailedServices {
                    Button(action: { showBookingSheet = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.system(size: 16))
                            Text("Book")
                                .font(KHOITheme.bodyBold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(KHOIColors.darkText)
                        .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal, KHOITheme.spacing_md)
            .padding(.bottom, KHOITheme.spacing_lg)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Cover Image
            Rectangle()
                .fill(KHOIColors.cardBackground)
                .frame(height: 180)
                .overlay(
                    AsyncImage(url: URL(string: artist.coverImageURL ?? "")) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        LinearGradient(
                            colors: [Color(hex: "8B4D5C"), Color(hex: "C4A07C")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                )
                .clipped()
            
            // Avatar
            Circle()
                .stroke(KHOIColors.background, lineWidth: 4)
                .background(Circle().fill(KHOIColors.cardBackground))
                .frame(width: 90, height: 90)
                .overlay(
                    AsyncImage(url: URL(string: artist.profileImageURL ?? "")) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .foregroundColor(KHOIColors.mutedText)
                    }
                    .clipShape(Circle())
                )
                .offset(x: 20, y: 45)
        }
        .padding(.bottom, 50)
    }
    
    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(artist.fullName)
                            .font(KHOITheme.heading2)
                            .foregroundColor(KHOIColors.darkText)
                        
                        // Verified badge for professionals
                        if artist.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(KHOIColors.accentBrown)
                                .font(.system(size: 16))
                        }
                    }
                    
                    Text("@\(artist.username)")
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.mutedText)
                }
                
                Spacer()
                
                // Add Friend button for non-professionals (not own profile)
                if !isProfessional && !isOwnProfile {
                    addFriendButton
                }
            }
            
            // Bio
            if !artist.bio.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(artist.bio)
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.darkText)
                        .lineLimit(isBioExpanded ? nil : 3)
                    
                    if artist.bio.count > 100 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isBioExpanded.toggle()
                            }
                        }) {
                            Text(isBioExpanded ? "view less" : "view more")
                                .font(KHOITheme.caption)
                                .foregroundColor(KHOIColors.mutedText)
                        }
                    }
                }
            }
            
            // Stats - only for professionals
            if isProfessional {
                HStack(spacing: 24) {
                    statItem(value: "\(artist.referralCount)", label: "Referrals")
                    statItem(value: String(format: "%.1f", artist.rating ?? 5.0), label: "Rating")
                    if !artist.city.isEmpty {
                        statItem(value: artist.city, label: "Location")
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, KHOITheme.spacing_md)
    }
    
    // MARK: - Add Friend Button
    @ViewBuilder
    private var addFriendButton: some View {
        if isFriend {
            // Already friends indicator
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12))
                Text("Friends")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(KHOIColors.mutedText)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(20)
        } else {
            Button(action: addFriend) {
                if isAddingFriend {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(KHOIColors.accentBrown)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 14))
                        Text("Add Friend")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(KHOIColors.accentBrown)
            .cornerRadius(20)
            .disabled(isAddingFriend)
        }
    }
    
    // MARK: - Non-Pro Saved Posts Section
    private var nonProSavedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text("SAVED")
                    .font(KHOITheme.headline)
                    .tracking(2)
                    .foregroundColor(KHOIColors.mutedText)
                
                Spacer()
            }
            .padding(.horizontal, KHOITheme.spacing_md)
            .padding(.top, KHOITheme.spacing_lg)
            
            if isLoadingSaved {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(KHOIColors.accentBrown)
                    Spacer()
                }
                .padding(.vertical, 40)
            } else if savedPosts.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 48))
                        .foregroundColor(KHOIColors.mutedText.opacity(0.5))
                    
                    Text("No saved posts yet")
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.mutedText)
                    
                    if isOwnProfile {
                        Text("Save looks you love from Discover")
                            .font(KHOITheme.caption)
                            .foregroundColor(KHOIColors.mutedText.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                // Saved posts grid
                savedPostsGrid
            }
        }
    }
    
    private var savedPostsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 2),
                GridItem(.flexible(), spacing: 2),
                GridItem(.flexible(), spacing: 2)
            ],
            spacing: 2
        ) {
            ForEach(savedPosts) { post in
                NavigationLink(destination: PostDetailView(post: post)) {
                    AsyncImage(url: URL(string: post.imageURL)) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(KHOIColors.chipBackground)
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(ProgressView().tint(KHOIColors.mutedText))
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
                        @unknown default:
                            Rectangle()
                                .fill(KHOIColors.chipBackground)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Tab Section (Professionals only)
    private var tabSection: some View {
        HStack(spacing: 0) {
            tabButton(title: "Posts")
            if artist.hasDetailedServices {
                tabButton(title: "Services")
            }
            tabButton(title: "Reviews")
        }
        .padding(.top, KHOITheme.spacing_lg)
        .padding(.bottom, KHOITheme.spacing_md)
        .padding(.horizontal, KHOITheme.spacing_md)
    }
    
    private func tabButton(title: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(KHOITheme.headline)
                .foregroundColor(selectedTab == title ? KHOIColors.darkText : KHOIColors.mutedText)
            
            Rectangle()
                .fill(selectedTab == title ? KHOIColors.accentBrown : Color.clear)
                .frame(height: 2)
        }
        .frame(maxWidth: .infinity)
        .onTapGesture {
            withAnimation { selectedTab = title }
        }
    }
    
    private func statItem(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(KHOITheme.headline)
                .foregroundColor(KHOIColors.darkText)
            Text(label)
                .font(KHOITheme.caption)
                .foregroundColor(KHOIColors.mutedText)
        }
    }
    
    // MARK: - Posts Grid (Professionals)
    private var postsGrid: some View {
        Group {
            if feedService.isLoading {
                ProgressView()
                    .tint(KHOIColors.accentBrown)
                    .padding(.top, 40)
            } else if feedService.userPosts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 48))
                        .foregroundColor(KHOIColors.mutedText.opacity(0.5))
                    
                    Text("No posts yet")
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.mutedText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 80)
            } else {
                InstagramGrid(posts: feedService.userPosts)
            }
        }
        .onAppear {
            feedService.fetchUserPosts(userId: artist.id)
        }
    }
    
    // MARK: - Services List (Professionals)
    private var servicesList: some View {
        VStack(spacing: 16) {
            if artist.hasDetailedServices {
                ForEach(artist.servicesDetailed) { service in
                    HStack(alignment: .top, spacing: 12) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: ServiceCategories.color(for: service.category)))
                            .frame(width: 4)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(service.name)
                                .font(KHOITheme.bodyBold)
                                .foregroundColor(KHOIColors.darkText)
                            
                            Text(service.category.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.5)
                                .foregroundColor(KHOIColors.darkText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: ServiceCategories.color(for: service.category)).opacity(0.3))
                                .cornerRadius(6)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                                    .foregroundColor(KHOIColors.mutedText)
                                Text("\(service.duration) min")
                                    .font(KHOITheme.caption)
                                    .foregroundColor(KHOIColors.mutedText)
                                
                                Text("•")
                                    .foregroundColor(KHOIColors.mutedText)
                                
                                Text("$\(Int(service.price))")
                                    .font(KHOITheme.caption)
                                    .foregroundColor(KHOIColors.darkText)
                                    .fontWeight(.semibold)
                            }
                            
                            if !service.description.isEmpty {
                                Text(service.description)
                                    .font(KHOITheme.caption)
                                    .foregroundColor(KHOIColors.mutedText)
                                    .lineLimit(2)
                                    .padding(.top, 2)
                            }
                        }
                        
                        Spacer()
                        
                        if !isOwnProfile {
                            Button(action: { showBookingSheet = true }) {
                                Text("Book")
                                    .font(KHOITheme.caption.bold())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(KHOIColors.darkText)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(KHOIColors.cardBackground)
                    .cornerRadius(12)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundColor(KHOIColors.mutedText.opacity(0.5))
                    
                    Text("No services listed yet.")
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.mutedText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
        .padding(KHOITheme.spacing_md)
    }
    
    // MARK: - Actions
    
    private func startChat() {
        guard let currentUser = authManager.currentUser,
              let uid = authManager.firebaseUID else { return }
        
        guard uid != artist.id else { return }
        
        isCreatingChat = true
        
        chatService.getOrCreateConversation(
            currentUser: (uid: uid, username: currentUser.username, fullName: currentUser.fullName),
            otherUser: (uid: artist.id, username: artist.username, fullName: artist.fullName),
            tag: isProfessional ? nil : .friend
        ) { result in
            switch result {
            case .success(let convId):
                self.fetchConversation(conversationId: convId)
            case .failure(let error):
                self.isCreatingChat = false
                print("Error creating conversation: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchConversation(conversationId: String) {
        let db = Firestore.firestore()
        db.collection("conversations").document(conversationId).getDocument { snapshot, error in
            self.isCreatingChat = false
            
            guard let document = snapshot, document.exists,
                  let conversation = Conversation(document: document) else {
                print("Error fetching conversation")
                return
            }
            
            self.activeConversation = conversation
            self.chatService.listenToMessages(conversationId: conversationId)
            self.showChat = true
        }
    }
    
    private func checkFriendStatus() {
        guard let userId = authManager.firebaseUID else { return }
        friendsService.fetchFriends(userId: userId) { friends in
            isFriend = friends.contains { $0.id == artist.id }
        }
    }
    
    private func addFriend() {
        guard let userId = authManager.firebaseUID else { return }
        
        isAddingFriend = true
        
        let friend = Friend(
            id: artist.id,
            fullName: artist.fullName,
            username: artist.username,
            profileImageURL: artist.profileImageURL
        )
        
        friendsService.addFriend(currentUserId: userId, friend: friend) { result in
            isAddingFriend = false
            switch result {
            case .success:
                withAnimation {
                    isFriend = true
                }
            case .failure(let error):
                print("Error adding friend: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadSavedPosts() {
        isLoadingSaved = true
        feedService.fetchUserSavedPosts(userId: artist.id) { postIds in
            // Now fetch the actual posts
            feedService.fetchPostsByIds(Array(postIds)) { posts in
                self.savedPosts = posts
                self.isLoadingSaved = false
            }
        }
    }
}
