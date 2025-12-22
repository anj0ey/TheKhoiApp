//
//  ReferFriendView.swift
//  TheKhoiApp
//
//  View for referring an artist to a friend
//

import SwiftUI

struct ReferFriendView: View {
    let artist: Artist
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    @StateObject private var friendsService = FriendsService()
    @StateObject private var referralService = ReferralService()
    @StateObject private var chatService = ChatService()
    
    @State private var searchText = ""
    @State private var selectedFriend: Friend?
    @State private var showConfirmation = false
    @State private var showSuccess = false
    @State private var isReferring = false
    
    var filteredFriends: [Friend] {
        if searchText.isEmpty {
            return friendsService.friends
        }
        return friendsService.searchFriends(query: searchText)
    }
    
    var body: some View {
        ZStack {
            KHOIColors.background.ignoresSafeArea()
            
            if showSuccess {
                successView
            } else {
                VStack(spacing: 0) {
                    // Header
                    header
                    
                    // Search bar
                    searchBar
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    // Friends list
                    if friendsService.isLoading {
                        Spacer()
                        ProgressView()
                            .tint(KHOIColors.accentBrown)
                        Spacer()
                    } else if filteredFriends.isEmpty {
                        emptyState
                    } else {
                        friendsList
                    }
                }
            }
            
            // Confirmation dialog overlay
            if showConfirmation, let friend = selectedFriend {
                confirmationDialog(friend: friend)
            }
        }
        .onAppear {
            if let userId = authManager.firebaseUID {
                friendsService.listenToFriends(userId: userId)
            }
        }
        .onDisappear {
            friendsService.stopListening()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(KHOIColors.darkText)
            }
            
            Spacer()
            
            Text(artist.displayHandle)
                .font(KHOITheme.headline)
                .foregroundColor(KHOIColors.darkText)
        }
        .padding()
        .background(KHOIColors.background)
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REFER A FRIEND")
                .font(KHOITheme.headline)
                .tracking(2)
                .foregroundColor(KHOIColors.mutedText)
            
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(KHOIColors.mutedText)
                
                TextField("Search your friend", text: $searchText)
                    .font(KHOITheme.body)
                    .textInputAutocapitalization(.never)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(KHOIColors.mutedText)
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Friends List
    
    private var friendsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredFriends) { friend in
                    FriendReferRow(friend: friend) {
                        selectedFriend = friend
                        showConfirmation = true
                    }
                }
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "person.2")
                .font(.system(size: 48))
                .foregroundColor(KHOIColors.mutedText.opacity(0.5))
            
            Text("No friends yet")
                .font(KHOITheme.headline)
                .foregroundColor(KHOIColors.darkText)
            
            Text("Add friends to refer artists to them")
                .font(KHOITheme.caption)
                .foregroundColor(KHOIColors.mutedText)
            
            Spacer()
        }
    }
    
    // MARK: - Confirmation Dialog
    
    private func confirmationDialog(friend: Friend) -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    showConfirmation = false
                    selectedFriend = nil
                }
            
            VStack(spacing: 20) {
                // Envelope image
                Image("mail")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 80)
                
                Text("time to spread the word!")
                    .font(KHOITheme.headline)
                    .foregroundColor(KHOIColors.darkText)
                
                Text("refer \(friend.fullName) to \(artist.displayHandle)?")
                    .font(KHOITheme.body)
                    .foregroundColor(KHOIColors.mutedText)
                
                HStack(spacing: 16) {
                    Button(action: {
                        showConfirmation = false
                        selectedFriend = nil
                    }) {
                        Text("Not now")
                            .font(KHOITheme.body)
                            .foregroundColor(KHOIColors.mutedText)
                    }
                    
                    Button(action: sendReferral) {
                        if isReferring {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Send referral")
                                .font(KHOITheme.bodyBold)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(KHOIColors.darkText)
                    .cornerRadius(8)
                    .disabled(isReferring)
                }
            }
            .padding(32)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.1), radius: 20)
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Success View
    
    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Envelope image
            Image("mail")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 120)
            
            VStack(spacing: 8) {
                Text("thank you for spreading the love.")
                    .font(KHOITheme.headline)
                    .foregroundColor(KHOIColors.darkText)
                
                Text("your referral has been sent!")
                    .font(KHOITheme.body)
                    .foregroundColor(KHOIColors.darkText)
            }
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Text("Back to Page")
                    .font(KHOITheme.bodyBold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(KHOIColors.darkText)
                    .cornerRadius(8)
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Actions
    
    private func sendReferral() {
        guard let friend = selectedFriend,
              let currentUser = authManager.currentUser,
              let userId = authManager.firebaseUID else { return }
        
        isReferring = true
        
        referralService.sendReferral(
            referrer: (id: userId, name: currentUser.fullName, username: currentUser.username),
            recipient: friend,
            artist: artist,
            chatService: chatService
        ) { result in
            isReferring = false
            showConfirmation = false
            
            switch result {
            case .success:
                withAnimation {
                    showSuccess = true
                }
            case .failure(let error):
                print("Referral failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Friend Refer Row

struct FriendReferRow: View {
    let friend: Friend
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Profile image
                AsyncImage(url: URL(string: friend.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(KHOIColors.mutedText)
                        )
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                // Name
                Text(friend.fullName)
                    .font(KHOITheme.body)
                    .foregroundColor(KHOIColors.darkText)
                
                Spacer()
                
                // Send icon
                Image(systemName: "paperplane")
                    .font(.system(size: 18))
                    .foregroundColor(KHOIColors.darkText)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        
        Divider()
            .padding(.leading, 78)
    }
}
