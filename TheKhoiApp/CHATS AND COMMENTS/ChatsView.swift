//
//  ChatsView.swift
//  TheKhoiApp
//
//  Chat list view with referral card support
//

import SwiftUI
import FirebaseFirestore

// MARK: - Chat Filter Category
enum ChatFilterCategory: String, CaseIterable {
    case all = "All"
    case friend = "Friend"
    case skin = "Skin"
    case nail = "Nail"
    case makeup = "Makeup"
    case hair = "Hair"
    case lashes = "Lashes"
    case brows = "Brows"
}

// MARK: - Chats View
struct ChatsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var chatService = ChatService()
    @State private var selectedFilter: ChatFilterCategory = .all
    @State private var showSearch = false
    @State private var searchText = ""
    
    var filteredConversations: [Conversation] {
        var conversations = chatService.conversations
        
        // Filter by category
        if selectedFilter != .all {
            conversations = conversations.filter { conversation in
                guard let tag = conversation.tag else { return false }
                return tag.rawValue.lowercased() == selectedFilter.rawValue.lowercased()
            }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            conversations = conversations.filter { conversation in
                guard let currentUserId = authManager.firebaseUID,
                      let otherParticipant = conversation.otherParticipant(currentUserId: currentUserId) else {
                    return false
                }
                return otherParticipant.fullName.lowercased().contains(searchText.lowercased()) ||
                       otherParticipant.username.lowercased().contains(searchText.lowercased())
            }
        }
        
        return conversations
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("CHATS")
                            .font(KHOITheme.headline)
                            .foregroundColor(KHOIColors.mutedText)
                            .tracking(2)
                        
                        Spacer()
                        
                        Button {
                            showSearch.toggle()
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.title3)
                                .foregroundColor(KHOIColors.darkText)
                        }
                    }
                    .padding(.horizontal, KHOITheme.spacing_lg)
                    .padding(.top, KHOITheme.spacing_md)
                    .padding(.bottom, KHOITheme.spacing_sm)
                    
                    // Search bar (when active)
                    if showSearch {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(KHOIColors.mutedText)
                            
                            TextField("Search chats...", text: $searchText)
                                .textInputAutocapitalization(.never)
                            
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(KHOIColors.mutedText)
                                }
                            }
                        }
                        .padding()
                        .background(KHOIColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md))
                        .padding(.horizontal)
                        .padding(.bottom, KHOITheme.spacing_sm)
                    }
                    
                    // Filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: KHOITheme.spacing_sm) {
                            ForEach(ChatFilterCategory.allCases, id: \.self) { category in
                                ChatFilterChip(
                                    title: category.rawValue,
                                    isSelected: selectedFilter == category
                                ) {
                                    selectedFilter = category
                                }
                            }
                        }
                        .padding(.horizontal, KHOITheme.spacing_lg)
                        .padding(.vertical, KHOITheme.spacing_sm)
                    }
                    
                    // Chat list
                    if chatService.isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: KHOIColors.accentBrown))
                        Spacer()
                    } else if filteredConversations.isEmpty {
                        Spacer()
                        VStack(spacing: KHOITheme.spacing_md) {
                            Image(systemName: "message")
                                .font(.largeTitle)
                                .foregroundColor(KHOIColors.mutedText)
                            Text("No conversations yet")
                                .font(KHOITheme.body)
                                .foregroundColor(KHOIColors.mutedText)
                            Text("Start chatting with artists and friends!")
                                .font(KHOITheme.caption)
                                .foregroundColor(KHOIColors.mutedText)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredConversations) { conversation in
                                    if let currentUserId = authManager.firebaseUID {
                                        NavigationLink {
                                            ChatDetailView(
                                                conversation: conversation,
                                                currentUserId: currentUserId,
                                                chatService: chatService
                                            )
                                        } label: {
                                            ChatRowView(
                                                conversation: conversation,
                                                currentUserId: currentUserId
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.top, KHOITheme.spacing_sm)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            if let userId = authManager.firebaseUID {
                chatService.listenToConversations(userId: userId)
            }
        }
        .onDisappear {
            chatService.stopListening()
        }
    }
}

// MARK: - Chat Filter Chip
struct ChatFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(KHOITheme.callout)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : KHOIColors.darkText)
                .padding(.horizontal, KHOITheme.spacing_lg)
                .padding(.vertical, KHOITheme.spacing_sm)
                .background(
                    Capsule()
                        .fill(isSelected ? KHOIColors.darkText : KHOIColors.cardBackground)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : KHOIColors.divider, lineWidth: 1)
                )
        }
    }
}

// MARK: - Chat Row View (UPDATED with real-time profile image fetching)
struct ChatRowView: View {
    let conversation: Conversation
    let currentUserId: String
    
    @State private var fetchedProfileImageURL: String? = nil
    @State private var hasFetchedImage = false
    
    private let db = Firestore.firestore()
    
    var otherParticipant: ChatParticipant? {
        conversation.otherParticipant(currentUserId: currentUserId)
    }
    
    var unreadCount: Int {
        conversation.unreadCountForUser(currentUserId)
    }
    
    // Use fetched URL if available, otherwise use conversation's stored URL
    var profileImageURL: String? {
        if let fetched = fetchedProfileImageURL, !fetched.isEmpty {
            return fetched
        }
        if let stored = otherParticipant?.profileImageURL, !stored.isEmpty {
            return stored
        }
        return nil
    }
    
    var body: some View {
        HStack(spacing: KHOITheme.spacing_md) {
            // Avatar with unread badge
            ZStack(alignment: .topTrailing) {
                if let imageURL = profileImageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure(_):
                            placeholderAvatar
                        case .empty:
                            ProgressView()
                                .frame(width: 56, height: 56)
                        @unknown default:
                            placeholderAvatar
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                } else {
                    placeholderAvatar
                }
                
                // Unread badge
                if unreadCount > 0 {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text("\(unreadCount)")
                                .font(KHOITheme.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                        .offset(x: -2, y: -2)
                }
            }
            
            // Name, tag, and message
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: KHOITheme.spacing_sm) {
                    Text(otherParticipant?.fullName ?? "Unknown")
                        .font(KHOITheme.headline)
                        .fontWeight(unreadCount > 0 ? .semibold : .regular)
                        .foregroundColor(KHOIColors.darkText)
                    
                    // Tag badge
                    if let tag = conversation.tag {
                        ChatTagBadge(tag: tag)
                    }
                }
                
                Text(conversation.lastMessage.isEmpty ? "Start a conversation" : conversation.lastMessage)
                    .font(KHOITheme.callout)
                    .foregroundColor(KHOIColors.mutedText)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Timestamp
            Text(conversation.formattedTimestamp)
                .font(KHOITheme.caption)
                .foregroundColor(KHOIColors.mutedText)
        }
        .padding(.horizontal, KHOITheme.spacing_lg)
        .padding(.vertical, KHOITheme.spacing_md)
        .onAppear {
            // Fetch profile image if not stored in conversation
            if !hasFetchedImage && (otherParticipant?.profileImageURL == nil || otherParticipant?.profileImageURL?.isEmpty == true) {
                fetchProfileImage()
            }
        }
    }
    
    private var placeholderAvatar: some View {
        Circle()
            .fill(KHOIColors.cardBackground)
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(KHOIColors.mutedText)
            )
    }
    
    private func fetchProfileImage() {
        guard let odUid = otherParticipant?.odUid else { return }
        hasFetchedImage = true
        
        // Try users collection first
        db.collection("users").document(odUid).getDocument { snapshot, error in
            if let data = snapshot?.data(),
               let imageURL = data["profileImageURL"] as? String,
               !imageURL.isEmpty {
                DispatchQueue.main.async {
                    self.fetchedProfileImageURL = imageURL
                }
                // Also update the conversation document for future loads
                self.updateConversationProfileImage(userId: odUid, imageURL: imageURL)
            } else {
                // Try artists collection
                self.db.collection("artists").document(odUid).getDocument { artistSnapshot, _ in
                    if let artistData = artistSnapshot?.data(),
                       let imageURL = artistData["profileImageURL"] as? String,
                       !imageURL.isEmpty {
                        DispatchQueue.main.async {
                            self.fetchedProfileImageURL = imageURL
                        }
                        self.updateConversationProfileImage(userId: odUid, imageURL: imageURL)
                    }
                }
            }
        }
    }
    
    private func updateConversationProfileImage(userId: String, imageURL: String) {
        db.collection("conversations").document(conversation.id).updateData([
            "participants.\(userId).profileImageURL": imageURL
        ]) { error in
            if let error = error {
                print("Error updating conversation profile image: \(error.localizedDescription)")
            } else {
                print("Updated conversation \(conversation.id) with profile image for user \(userId)")
            }
        }
    }
}

// MARK: - Chat Tag Badge
struct ChatTagBadge: View {
    let tag: ChatTag
    
    var body: some View {
        Text(tag.rawValue.uppercased())
            .font(KHOITheme.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color(hex: tag.color))
            )
    }
}

// MARK: - Chat Detail View
struct ChatDetailView: View {
    let conversation: Conversation
    let currentUserId: String
    @ObservedObject var chatService: ChatService
    @EnvironmentObject var authManager: AuthManager
    
    @State private var messageText = ""
    @Environment(\.dismiss) private var dismiss
    
    var otherParticipant: ChatParticipant? {
        conversation.otherParticipant(currentUserId: currentUserId)
    }
    
    var body: some View {
        ZStack {
            KHOIColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: KHOITheme.spacing_md) {
                            ForEach(chatService.currentMessages) { message in
                                MessageBubble(
                                    message: message,
                                    isFromCurrentUser: message.senderId == currentUserId
                                )
                                .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: chatService.currentMessages.count) { oldCount, newCount in
                        if let lastMessage = chatService.currentMessages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Message input
                HStack(spacing: KHOITheme.spacing_md) {
                    TextField("Type a message...", text: $messageText)
                        .padding()
                        .background(KHOIColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_pill))
                    
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(messageText.isEmpty ? KHOIColors.mutedText : KHOIColors.accentBrown)
                    }
                    .disabled(messageText.isEmpty)
                }
                .padding()
                .background(KHOIColors.background)
            }
        }
        .navigationTitle(otherParticipant?.fullName ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: KHOITheme.spacing_sm) {
                    Text(otherParticipant?.fullName ?? "Chat")
                        .font(KHOITheme.headline)
                        .foregroundColor(KHOIColors.darkText)
                    
                    if let tag = conversation.tag {
                        ChatTagBadge(tag: tag)
                    }
                }
            }
        }
        .onAppear {
            chatService.listenToMessages(conversationId: conversation.id)
            chatService.markConversationAsRead(conversationId: conversation.id, userId: currentUserId)
        }
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let senderName = authManager.currentUser?.fullName ?? "Unknown"
        let otherUserId = otherParticipant?.odUid ?? ""
        
        chatService.sendMessage(
            conversationId: conversation.id,
            senderId: currentUserId,
            senderName: senderName,
            text: text,
            otherUserId: otherUserId
        ) { result in
            switch result {
            case .success:
                messageText = ""
            case .failure(let error):
                print("Failed to send message: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Message Bubble (Updated with Referral Card)
struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer() }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Check if this is a referral message
                if message.isReferral, let referralData = message.referralData {
                    ReferralCard(referralData: referralData, isFromCurrentUser: isFromCurrentUser)
                } else {
                    // Regular text message
                    Text(message.text)
                        .font(KHOITheme.body)
                        .foregroundColor(isFromCurrentUser ? .white : KHOIColors.darkText)
                        .padding(.horizontal, KHOITheme.spacing_md)
                        .padding(.vertical, KHOITheme.spacing_sm)
                        .background(
                            isFromCurrentUser ? KHOIColors.accentBrown : KHOIColors.cardBackground
                        )
                        .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_lg))
                }
                
                Text(message.formattedTime)
                    .font(KHOITheme.caption2)
                    .foregroundColor(KHOIColors.mutedText)
            }
            
            if !isFromCurrentUser { Spacer() }
        }
    }
}

// MARK: - Referral Card (Tappable)
struct ReferralCard: View {
    let referralData: ReferralMessageData
    let isFromCurrentUser: Bool
    
    var body: some View {
        NavigationLink(destination: ArtistProfileLoader(artistId: referralData.artistId)) {
            VStack(spacing: 0) {
                // Artist info
                HStack(spacing: 12) {
                    // Profile image
                    AsyncImage(url: URL(string: referralData.artistProfileImageURL ?? "")) { image in
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
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(referralData.artistName)
                            .font(KHOITheme.bodyBold)
                            .foregroundColor(KHOIColors.darkText)
                        
                        Text(referralData.displayHandle)
                            .font(KHOITheme.caption)
                            .foregroundColor(KHOIColors.mutedText)
                        
                        // Rating and location
                        HStack(spacing: 8) {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(KHOIColors.accentBrown)
                                Text(String(format: "%.1f", referralData.artistRating))
                                    .font(.system(size: 11))
                                    .foregroundColor(KHOIColors.mutedText)
                            }
                            
                            if !referralData.artistCity.isEmpty {
                                Text("•")
                                    .foregroundColor(KHOIColors.mutedText)
                                Text(referralData.artistCity)
                                    .font(.system(size: 11))
                                    .foregroundColor(KHOIColors.mutedText)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(KHOIColors.mutedText)
                }
                
                // Services preview
                if !referralData.artistServices.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(referralData.artistServices.prefix(3), id: \.self) { service in
                            Text(service)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(KHOIColors.darkText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.top, 10)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
            .frame(maxWidth: 280)
        }
        .buttonStyle(.plain)
    }
}
