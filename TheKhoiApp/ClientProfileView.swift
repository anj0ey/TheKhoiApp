//
//  ClientProfileView.swift
//  TheKhoiApp
//
//  Created by Paige McNamara-Pittler on 12/2/25.
//

import SwiftUI

struct ClientProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    
    // FeedService to fetch posts
    @StateObject private var feedService = FeedService()
    
    // UI State
    @State private var selectedTab: ProfileSection = .myPosts
    @State private var showBusinessSetup = false // 👈 Controls the Onboarding Sheet

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
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 32))
                                                .foregroundColor(KHOIColors.mutedText)
                                        )
                                        .offset(x: 24, y: 40)
                                )
                        }
                        .padding(.bottom, 40)

                        // MARK: - User Info
                        VStack(spacing: 4) {
                            Text(authManager.currentUser?.fullName ?? "Guest User")
                                .font(KHOITheme.heading2)
                                .foregroundColor(KHOIColors.darkText)
                            
                            Text("@\(authManager.currentUser?.username ?? "username")")
                                .font(KHOITheme.body)
                                .foregroundColor(KHOIColors.mutedText)
                        }

                        // MARK: - Business Onboarding / Toggle Section
                        VStack(spacing: 12) {
                            if authManager.isBusinessMode {
                                // CASE A: Already in Business Mode -> Show Toggle to switch back
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Business Mode Active")
                                            .font(KHOITheme.headline)
                                        Text("You can now post and manage bookings.")
                                            .font(KHOITheme.caption)
                                            .foregroundColor(KHOIColors.mutedText)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $authManager.isBusinessMode)
                                        .labelsHidden()
                                        .tint(KHOIColors.accentBrown)
                                }
                            } else {
                                // CASE B: Client Mode -> Show "Create Business" OR "Switch"
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Service Provider?")
                                            .font(KHOITheme.headline)
                                        Text("Create a business page to post work.")
                                            .font(KHOITheme.caption)
                                            .foregroundColor(KHOIColors.mutedText)
                                    }
                                    Spacer()
                                    
                                    Button(action: {
                                        // Open the setup sheet
                                        showBusinessSetup = true
                                    }) {
                                        Text("Get Started")
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

                        // MARK: - Content Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 1) {
                            if selectedTab == .myPosts {
                                // In the future: Filter posts by authManager.firebaseUID
                                ForEach(feedService.posts.prefix(4)) { post in
                                    realPostTile(post: post)
                                }
                            } else {
                                emptyState(text: "No saved posts yet.")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { authManager.logOut() }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(KHOIColors.darkText)
                    }
                }
            }
            // 👇 THIS IS THE KEY FIX: Connects the Onboarding Sheet
            .sheet(isPresented: $showBusinessSetup) {
                BusinessOnboardingView()
                    .environmentObject(authManager)
            }
            .onAppear {
                feedService.fetchPosts()
            }
        }
    }
    
    // Helper Components
    private func tabButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(KHOITheme.caption)
                .padding(.horizontal, KHOITheme.spacing_md)
                .padding(.vertical, 8)
                .background(isSelected ? KHOIColors.accentBrown.opacity(0.1) : Color.clear)
                .foregroundColor(isSelected ? KHOIColors.accentBrown : KHOIColors.mutedText)
                .cornerRadius(12)
        }
        .frame(maxWidth: .infinity)
    }

    private func realPostTile(post: Post) -> some View {
        AsyncImage(url: URL(string: post.imageURL)) { img in
            img.image?.resizable().aspectRatio(contentMode: .fill)
        }
        .frame(height: 160)
        .clipped()
    }

    private func emptyState(text: String) -> some View {
        Text(text)
            .padding(40)
            .foregroundColor(KHOIColors.mutedText)
    }
}
