//
//  PostDetailView.swift
//  TheKhoiApp
//
//  Post detail/preview view with comments and save functionality
//

import SwiftUI

struct PostDetailView: View {
    let post: Post
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var commentService = CommentService()
    @StateObject private var feedService = FeedService()
    @StateObject private var reviewService = ReviewService()
    
    @State private var isSaved = false
    @State private var saveCount: Int
    @State private var commentText = ""
    @State private var isSubmittingComment = false
    @State private var reviewerAvatars: [String] = []
    @State private var reviewCount = 0
    
    // Initialize with post's save count
    init(post: Post) {
        self.post = post
        _saveCount = State(initialValue: post.saveCount)
    }
    
    var body: some View {
        ZStack {
            KHOIColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Artist info row
                        artistInfoRow
                        
                        // Post image
                        postImage
                        
                        // Reviews summary row
                        reviewsSummaryRow
                        
                        // Save count
                        saveCountRow
                        
                        // Comments section
                        commentsSection
                    }
                    .padding(.bottom, 100)
                }
                
                // Comment input
                commentInputBar
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadData()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(KHOIColors.darkText)
            }
            
            Spacer()
            
            Text("POST")
                .font(KHOITheme.headline)
                .foregroundColor(KHOIColors.mutedText)
                .tracking(2)
            
            Spacer()
            
            /*
            // Message button
            NavigationLink(destination: ArtistProfileLoader(artistId: post.artistId)) {
                Image(systemName: "bubble.right")
                    .font(.system(size: 18))
                    .foregroundColor(KHOIColors.darkText)
            }
            */
        }
        .padding()
        .background(KHOIColors.background)
    }
    
    // MARK: - Artist Info Row
    
    private var artistInfoRow: some View {
        HStack(spacing: 12) {
            // Artist avatar
            NavigationLink(destination: ArtistProfileLoader(artistId: post.artistId)) {
                AsyncImage(url: URL(string: post.artistProfileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            }
            
            // Artist handle - tappable to navigate to profile
            NavigationLink(destination: ArtistProfileLoader(artistId: post.artistId)) {
                Text(post.artistHandle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(KHOIColors.darkText)
            }
            
            Spacer()
            
            // Tag badge
            Text(post.tag.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(hex: ServiceCategories.color(for: post.tag)))
                .cornerRadius(4)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Post Image
    
    private var postImage: some View {
        AsyncImage(url: URL(string: post.imageURL)) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(ProgressView())
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
            case .failure:
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(KHOIColors.mutedText)
                    )
            @unknown default:
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
            }
        }
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Reviews Summary Row
    
    private var reviewsSummaryRow: some View {
        NavigationLink(destination: ArtistProfileLoader(artistId: post.artistId)) {
            HStack(spacing: 8) {
                // Overlapping avatars
                HStack(spacing: -8) {
                    ForEach(reviewerAvatars.prefix(3), id: \.self) { avatarURL in
                        AsyncImage(url: URL(string: avatarURL)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(KHOIColors.background, lineWidth: 2)
                        )
                    }
                }
                
                Text("\(reviewCount) client reviews")
                    .font(.system(size: 13))
                    .foregroundColor(KHOIColors.mutedText)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(KHOIColors.mutedText)
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Save Count Row
    
    private var saveCountRow: some View {
        HStack(spacing: 8) {
            Button(action: toggleSave) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 16))
                    .foregroundColor(isSaved ? KHOIColors.accentBrown : KHOIColors.darkText)
            }
            
            Text(formatSaveCount(saveCount))
                .font(.system(size: 13))
                .foregroundColor(KHOIColors.mutedText)
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    // MARK: - Comments Section
    
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("COMMENTS")
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundColor(KHOIColors.darkText)
                .padding(.horizontal)
            
            if commentService.isLoading {
                ProgressView()
                    .tint(KHOIColors.accentBrown)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if commentService.comments.isEmpty {
                Text("No comments yet. Be the first!")
                    .font(.system(size: 13))
                    .foregroundColor(KHOIColors.mutedText)
                    .padding(.horizontal)
            } else {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(commentService.comments) { comment in
                        CommentRow(comment: comment)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Comment Input Bar
    
    private var commentInputBar: some View {
        HStack(spacing: 12) {
            // Current user avatar
            if let profileURL = authManager.currentUser?.profileImageURL {
                AsyncImage(url: URL(string: profileURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(hex: "B5D6E8"))
                    .frame(width: 36, height: 36)
            }
            
            // Text field
            TextField("Leave a comment...", text: $commentText)
                .font(.system(size: 14))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(KHOIColors.cardBackground)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            
            // Send button
            Button(action: submitComment) {
                if isSubmittingComment {
                    ProgressView()
                        .tint(KHOIColors.accentBrown)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(commentText.isEmpty ? Color.gray.opacity(0.3) : KHOIColors.accentBrown)
                }
            }
            .disabled(commentText.isEmpty || isSubmittingComment)
        }
        .padding()
        .background(KHOIColors.background)
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: -5)
    }
    
    // MARK: - Helper Functions
    
    private func loadData() {
        // Load comments
        commentService.fetchComments(forPostId: post.id)
        
        // Check if current user has saved this post
        if let userId = authManager.firebaseUID {
            feedService.fetchUserSavedPosts(userId: userId) { savedIds in
                isSaved = savedIds.contains(post.id)
            }
        }
        
        // Load review summary
        reviewService.fetchReviews(forArtistId: post.artistId)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            reviewerAvatars = reviewService.reviews
                .filter { !$0.isAnonymous }
                .compactMap { $0.authorProfileImageURL }
            reviewCount = reviewService.reviewStats.totalReviews
        }
    }
    
    private func toggleSave() {
        guard let userId = authManager.firebaseUID else { return }
        
        isSaved.toggle()
        saveCount += isSaved ? 1 : -1
        
        feedService.toggleSavePost(postId: post.id, userId: userId, isSaving: isSaved)
    }
    
    private func submitComment() {
        guard let currentUser = authManager.currentUser,
              let userId = authManager.firebaseUID,
              !commentText.isEmpty else { return }
        
        isSubmittingComment = true
        
        commentService.addComment(
            text: commentText,
            postId: post.id,
            authorId: userId,
            authorName: currentUser.fullName,
            authorUsername: currentUser.username,
            authorProfileImageURL: currentUser.profileImageURL
        ) { result in
            isSubmittingComment = false
            
            switch result {
            case .success:
                commentText = ""
            case .failure(let error):
                print("Error submitting comment: \(error)")
            }
        }
    }
    
    private func formatSaveCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk saved", Double(count) / 1000.0)
        }
        return "\(count) saved"
    }
}

// MARK: - Comment Row

struct CommentRow: View {
    let comment: Comment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Author avatar
            AsyncImage(url: URL(string: comment.authorProfileImageURL ?? "")) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.2))
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            
            // Comment content
            VStack(alignment: .leading, spacing: 4) {
                Text(comment.text)
                    .font(.system(size: 14))
                    .foregroundColor(KHOIColors.darkText)
                    .lineSpacing(2)
                
                Text(comment.timeAgo)
                    .font(.system(size: 11))
                    .foregroundColor(KHOIColors.mutedText)
            }
            
            Spacer()
        }
    }
}

// MARK: - Tappable Post Card for Discovery

struct TappablePostCard: View {
    let post: Post
    let isSaved: Bool
    let onSaveTap: () -> Void
    
    var body: some View {
        NavigationLink(destination: PostDetailView(post: post)) {
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
                
                // Save button row
                HStack(spacing: 6) {
                    Button(action: onSaveTap) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 14))
                            .foregroundColor(isSaved ? KHOIColors.accentBrown : KHOIColors.darkText)
                    }
                    
                    Text(formatSaveCount(post.saveCount))
                        .font(.system(size: 11))
                        .foregroundColor(KHOIColors.mutedText)
                }
                .padding(.top, 8)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatSaveCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}

// MARK: - Tappable Grid Post Tile

struct TappableGridPostTile: View {
    let post: Post
    
    var body: some View {
        NavigationLink(destination: PostDetailView(post: post)) {
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
        .buttonStyle(PlainButtonStyle())
    }
}
