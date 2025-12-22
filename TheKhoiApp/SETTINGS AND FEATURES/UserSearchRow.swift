//
//  UserSearchRow.swift
//  TheKhoiApp
//
//  Search result row with Add Friend functionality
//

import SwiftUI

struct UserSearchRow: View {
    let user: UserSearchResult
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var friendsService = FriendsService()
    @State private var isFriend = false
    @State private var isAdding = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile image
            AsyncImage(url: URL(string: user.profileImageURL ?? "")) { image in
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
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(user.fullName)
                        .font(KHOITheme.bodyBold)
                        .foregroundColor(KHOIColors.darkText)
                    
                    // Pro badge
                    if user.isArtist {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(KHOIColors.accentBrown)
                    }
                }
                
                Text("@\(user.username)")
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.mutedText)
            }
            
            Spacer()
            
            // Add Friend button (only for non-artists and not self)
            if !user.isArtist && user.id != authManager.firebaseUID {
                addFriendButton
            }
        }
        .padding(.horizontal, KHOITheme.spacing_md)
        .padding(.vertical, 10)
        .onAppear {
            checkFriendStatus()
        }
    }
    
    @ViewBuilder
    private var addFriendButton: some View {
        if isFriend {
            // Already friends
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12))
                Text("Friends")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(KHOIColors.mutedText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(16)
        } else {
            Button(action: addFriend) {
                if isAdding {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(KHOIColors.accentBrown)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 12))
                        Text("Add")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(KHOIColors.accentBrown)
            .cornerRadius(16)
            .disabled(isAdding)
        }
    }
    
    private func checkFriendStatus() {
        guard let userId = authManager.firebaseUID else { return }
        friendsService.fetchFriends(userId: userId) { friends in
            isFriend = friends.contains { $0.id == user.id }
        }
    }
    
    private func addFriend() {
        guard let userId = authManager.firebaseUID else { return }
        
        isAdding = true
        
        let friend = Friend(
            id: user.id,
            fullName: user.fullName,
            username: user.username,
            profileImageURL: user.profileImageURL
        )
        
        friendsService.addFriend(currentUserId: userId, friend: friend) { result in
            isAdding = false
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
                    .overlay(ProgressView())
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
            }
        }
        .cornerRadius(8)
    }
}
