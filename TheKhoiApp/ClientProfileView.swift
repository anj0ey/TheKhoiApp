//
//  ClientProfileView.swift
//  TheKhoiApp
//
//  Created by Paige McNamara-Pittler on 12/2/25.
//

import SwiftUI

struct ClientProfileView: View {
    @EnvironmentObject var authManager: AuthManager

    // In the future these will come from backend / FeedService
    // For now we’ll just mock a couple arrays to drive the layout.
    private let mockMyPosts = Array(0..<12)
    private let mockSavedPosts = Array(0..<8)

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
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 32))
                                                .foregroundColor(KHOIColors.mutedText)
                                        )
                                )
                        }
                        .padding(.bottom, 40)

                        // MARK: - Name / handle / Edit
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(authManager.currentUser?.fullName ?? "Your name")
                                    .font(KHOITheme.heading3)
                                    .foregroundColor(KHOIColors.darkText)

                                Text("@\(authManager.currentUser?.username ?? "username")")
                                    .font(KHOITheme.caption)
                                    .foregroundColor(KHOIColors.mutedText)

                                if let location = authManager.currentUser?.location,
                                   !location.isEmpty {
                                    Text(location)
                                        .font(KHOITheme.caption)
                                        .foregroundColor(KHOIColors.mutedText)
                                }
                            }

                            Spacer()

                            NavigationLink {
                                EditProfileView()
                            } label: {
                                Text("Edit")
                                    .font(KHOITheme.caption)
                                    .padding(.horizontal, KHOITheme.spacing_md)
                                    .padding(.vertical, 6)
                                    .background(KHOIColors.cardBackground)
                                    .cornerRadius(999)
                            }
                        }
                        .padding(.horizontal, KHOITheme.spacing_md)

                        // MARK: - Stats
                        HStack(spacing: 24) {
                            profileStat(title: "POSTS",
                                        value: "\(mockMyPosts.count)")
                            profileStat(title: "SAVED",
                                        value: "\(mockSavedPosts.count)")
                            profileStat(title: "CLAIMED",
                                        value: "0") // TODO: wire real count later

                            Spacer()
                        }
                        .padding(.horizontal, KHOITheme.spacing_md)

                        // MARK: - Segmented control (My Posts / Saved)
                        HStack(spacing: 8) {
                            segmentButton(title: "My posts", isSelected: selectedTab == .myPosts) {
                                selectedTab = .myPosts
                            }

                            segmentButton(title: "Saved", isSelected: selectedTab == .saved) {
                                selectedTab = .saved
                            }

                            Spacer()
                        }
                        .padding(.horizontal, KHOITheme.spacing_md)
                        .padding(.top, KHOITheme.spacing_sm)

                        // MARK: - Grid of posts
                        let columns = [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ]

                        LazyVGrid(columns: columns, spacing: 8) {
                            if selectedTab == .myPosts {
                                if mockMyPosts.isEmpty {
                                    emptyState(text: "You haven’t posted yet.")
                                } else {
                                    ForEach(mockMyPosts, id: \.self) { index in
                                        mockPostTile(index: index)
                                    }
                                }
                            } else {
                                if mockSavedPosts.isEmpty {
                                    emptyState(text: "You haven’t saved any posts yet.")
                                } else {
                                    ForEach(mockSavedPosts, id: \.self) { index in
                                        mockPostTile(index: index)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, KHOITheme.spacing_md)
                        .padding(.bottom, 80) // space for tab bar + FAB
                    }
                }

                // MARK: - Floating "+" button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        NavigationLink {
                            CreatePostView()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(KHOIColors.accent)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(KHOIColors.darkText)
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private func profileStat(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(KHOITheme.bodyBold)
                .foregroundColor(KHOIColors.darkText)
            Text(title)
                .font(KHOITheme.caption)
                .foregroundColor(KHOIColors.mutedText)
        }
    }

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
                    ? KHOIColors.accent.opacity(0.12)
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

    private func mockPostTile(index: Int) -> some View {
        Rectangle()
            .fill(KHOIColors.cardBackground)
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(KHOIColors.mutedText)
            )
            .aspectRatio(1, contentMode: .fit)
            .cornerRadius(10)
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