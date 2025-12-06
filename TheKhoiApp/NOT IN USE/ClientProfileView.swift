//
//  ClientProfileView.swift
//  TheKhoiApp
//
// NOT IN USE

import SwiftUI

struct ClientProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var feedService = FeedService()
    
    @State private var selectedTab: ProfileSection = .myPosts
    @State private var showBusinessSetup = false
    @State private var showSettings = false

    enum ProfileSection {
        case myPosts
        case saved
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {

                    // MARK: - Banner + Avatar (Full Bleed)
                    ZStack(alignment: .bottom) {
                        // Banner with gradient - stretches to fill top
                        GeometryReader { geo in
                            let minY = geo.frame(in: .global).minY
                            
                            // Cover image or gradient
                            if let coverURL = authManager.currentUser?.coverImageURL,
                               !coverURL.isEmpty,
                               let url = URL(string: coverURL) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    LinearGradient(
                                        colors: [Color(hex: "8B4D5C"), Color(hex: "C4A07C")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                }
                                .frame(
                                    width: geo.size.width,
                                    height: minY > 0 ? 220 + minY : 220
                                )
                                .offset(y: minY > 0 ? -minY : 0)
                            } else {
                                LinearGradient(
                                    colors: [Color(hex: "8B4D5C"), Color(hex: "C4A07C")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .frame(
                                    width: geo.size.width,
                                    height: minY > 0 ? 220 + minY : 220
                                )
                                .offset(y: minY > 0 ? -minY : 0)
                            }
                        }
                        .frame(height: 220)
                        
                        // Settings button (top right)
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: { showSettings = true }) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                        .padding(10)
                                        .background(Color.black.opacity(0.2))
                                        .clipShape(Circle())
                                }
                                .padding(.trailing, 16)
                            }
                            .padding(.top, 50) // Account for status bar
                            Spacer()
                        }
                        .frame(height: 220)

                        // Avatar - positioned to overlap banner bottom
                        Circle()
                            .fill(KHOIColors.background)
                            .frame(width: 96, height: 96)
                            .overlay(
                                profileImageView
                                    .frame(width: 88, height: 88)
                                    .clipShape(Circle())
                            )
                            .offset(y: 48)
                    }
                    .frame(height: 220)
                    .padding(.bottom, 56)

                        // MARK: - User Info
                        VStack(spacing: 4) {
                            Text(authManager.currentUser?.fullName ?? "Guest User")
                                .font(KHOITheme.heading2)
                                .foregroundColor(KHOIColors.darkText)
                            
                            Text("@\(authManager.currentUser?.username ?? "username")")
                                .font(KHOITheme.body)
                                .foregroundColor(KHOIColors.mutedText)
                            
                            if let bio = authManager.currentUser?.bio, !bio.isEmpty {
                                Text(bio)
                                    .font(KHOITheme.caption)
                                    .foregroundColor(KHOIColors.mutedText)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.top, KHOITheme.spacing_sm)

                        // MARK: - Business Onboarding Section
                        if !authManager.hasBusinessProfile {
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
                                            Text("Apply to become a verified pro.")
                                                .font(KHOITheme.caption)
                                                .foregroundColor(KHOIColors.mutedText)
                                        }
                                        Spacer()
                                        
                                        Button(action: { showBusinessSetup = true }) {
                                            Text("Apply Now")
                                                .font(KHOITheme.caption)
                                                .bold()
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(KHOIColors.darkText)
                                                .foregroundColor(.white)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(KHOIColors.cardBackground)
                            .cornerRadius(12)
                            .padding(.horizontal, KHOITheme.spacing_md)
                            .padding(.top, KHOITheme.spacing_lg)
                        }

                        // MARK: - Tabs
                        HStack(spacing: 0) {
                            tabButton(title: "My Posts", isSelected: selectedTab == .myPosts) {
                                selectedTab = .myPosts
                            }
                            tabButton(title: "Saved", isSelected: selectedTab == .saved) {
                                selectedTab = .saved
                            }
                        }
                        .padding(.horizontal, KHOITheme.spacing_md)
                        .padding(.top, KHOITheme.spacing_lg)

                        // MARK: - Content Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
                            if selectedTab == .myPosts {
                                if feedService.userPosts.isEmpty {
                                    emptyState(text: "No posts yet.")
                                } else {
                                    ForEach(feedService.userPosts) { post in
                                        realPostTile(post: post)
                                    }
                                }
                            } else {
                                if feedService.savedPosts.isEmpty {
                                    emptyState(text: "No saved posts yet.")
                                } else {
                                    ForEach(feedService.savedPosts) { post in
                                        realPostTile(post: post)
                                    }
                                }
                            }
                        }
                        .padding(.top, KHOITheme.spacing_md)
                        .padding(.bottom, 100)
                    }
                }
            .background(KHOIColors.background)
            .ignoresSafeArea(edges: .top)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showBusinessSetup) {
                ProOnboardingView()
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                        .environmentObject(authManager)
                }
            }
            .onAppear {
                if let userId = authManager.firebaseUID {
                    feedService.fetchUserPosts(userId: userId)
                    feedService.fetchUserSavedPosts(userId: userId) { _ in }
                }
            }
        }
    }
    
    // MARK: - Profile Image View
    @ViewBuilder
    private var profileImageView: some View {
        if let profileURL = authManager.currentUser?.profileImageURL,
           !profileURL.isEmpty,
           let url = URL(string: profileURL) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(KHOIColors.chipBackground)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(KHOIColors.mutedText)
                    )
            }
        } else {
            Circle()
                .fill(KHOIColors.cardBackground)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 32))
                        .foregroundColor(KHOIColors.mutedText)
                )
        }
    }
    
    // MARK: - Tab Button
    private func tabButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(KHOITheme.bodyBold)
                    .foregroundColor(isSelected ? KHOIColors.darkText : KHOIColors.mutedText)
                
                Rectangle()
                    .fill(isSelected ? KHOIColors.accentBrown : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Post Tile
    private func realPostTile(post: Post) -> some View {
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
            @unknown default:
                Rectangle()
                    .fill(KHOIColors.chipBackground)
            }
        }
    }

    // MARK: - Empty State
    private func emptyState(text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 40))
                .foregroundColor(KHOIColors.mutedText.opacity(0.5))
            Text(text)
                .font(KHOITheme.body)
                .foregroundColor(KHOIColors.mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .gridCellColumns(2)
    }
}
