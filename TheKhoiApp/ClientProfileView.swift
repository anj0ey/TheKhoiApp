//
//  ClientProfileView.swift
//  TheKhoiApp
//
//  Created by Paige McNamara-Pittler on 12/2/25.
//

import SwiftUI

struct ClientProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    
    // 1. ADDED: FeedService to fetch real data
    @StateObject private var feedService = FeedService()

    @State private var selectedTab: ProfileSection = .myPosts

    enum ProfileSection {
        case myPosts
        case saved
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: KHOITheme.spacing_md) {

                        // MARK: - Banner + Avatar
                        ZStack(alignment: .bottomLeading) {
                            Rectangle()
                                .fill(KHOIColors.cardBackground)
                                .frame(height: 160)

                            Circle()
                                .fill(KHOIColors.background)
                                .frame(width: 92, height: 92)
                                .offset(x: 24, y: 40)
                                .overlay(
                                    Circle()
                                        .fill(KHOIColors.cardBackground)
                                        .frame(width: 84, height: 84)
                                        .overlay(
                                            // TODO: Eventually load authManager.currentUser?.profileImageURL here
                                            Image(systemName: "person.fill")
                                                .foregroundColor(KHOIColors.mutedText)
                                                .font(.largeTitle)
                                        )
                                        .offset(x: 24, y: 40)
                                )
                        }
                        .padding(.bottom, 40)

                        // MARK: - Info
                        VStack(alignment: .leading, spacing: 4) {
                            // 2. UPDATED: Use real user data
                            Text(authManager.currentUser?.fullName ?? "Your Name")
                                .font(KHOITheme.heading2)
                                .foregroundColor(KHOIColors.darkText)
                            
                            Text("@\(authManager.currentUser?.username ?? "username")")
                                .font(KHOITheme.body)
                                .foregroundColor(KHOIColors.mutedText)
                            
                            // Optional: Bio if you have it
                            if let bio = authManager.currentUser?.bio, !bio.isEmpty {
                                Text(bio)
                                    .font(KHOITheme.caption)
                                    .foregroundColor(KHOIColors.darkText)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, KHOITheme.spacing_md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Edit Profile Button
                        NavigationLink(destination: EditProfileView()) {
                            Text("Edit Profile")
                                .font(KHOITheme.bodyBold)
                                .foregroundColor(KHOIColors.darkText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(KHOIColors.mutedText.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, KHOITheme.spacing_md)

                        // MARK: - Tabs
                        HStack(spacing: KHOITheme.spacing_md) {
                            segmentButton(title: "My Posts", isSelected: selectedTab == .myPosts) {
                                selectedTab = .myPosts
                            }
                            segmentButton(title: "Saved", isSelected: selectedTab == .saved) {
                                selectedTab = .saved
                            }
                            Spacer()
                        }
                        .padding(.horizontal, KHOITheme.spacing_md)
                        .padding(.top, KHOITheme.spacing_sm)

                        // MARK: - Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
                            
                            if selectedTab == .myPosts {
                                // 3. UPDATED: Logic to show real posts
                                if feedService.isLoading {
                                    ProgressView().padding()
                                } else if feedService.posts.isEmpty {
                                    emptyState(text: "No posts yet. Tap + to create one!")
                                } else {
                                    ForEach(feedService.posts) { post in
                                        realPostTile(post: post)
                                    }
                                }
                            } else {
                                // Saved posts placeholder
                                emptyState(text: "Saved posts coming soon")
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            // 4. ADDED: Settings Button
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .foregroundColor(KHOIColors.darkText)
                    }
                }
            }
            // 5. ADDED: Fetch data when view appears
            .onAppear {
                if let uid = authManager.firebaseUID {
                    feedService.fetchPosts(forUserId: uid)
                }
            }
        }
    }

    // MARK: - Helper Views

    private func segmentButton(title: String,
                               isSelected: Bool,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(KHOITheme.caption)
                .padding(.horizontal, KHOITheme.spacing_md)
                .padding(.vertical, 8)
                .background(
                    isSelected
                    ? KHOIColors.accentBrown.opacity(0.12) // Updated to accentBrown
                    : KHOIColors.cardBackground
                )
                .foregroundColor(
                    isSelected
                    ? KHOIColors.accentBrown // Updated to accentBrown
                    : KHOIColors.darkText
                )
                .cornerRadius(999)
        }
    }

    // 6. ADDED: Tile that loads real images
    private func realPostTile(post: Post) -> some View {
        AsyncImage(url: URL(string: post.imageURL)) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipped()
    }

    private func emptyState(text: String) -> some View {
        Text(text)
            .font(KHOITheme.body)
            .foregroundColor(KHOIColors.mutedText)
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        ClientProfileView()
            .environmentObject(AuthManager())
    }
}
