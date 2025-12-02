//
//  ChatsView.swift
//  TheKhoiApp
//
//  Chat list view matching the design
//

import SwiftUI

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
        .buttonStyle(.plain)
    }
}

// MARK: - Chat Row View
struct ChatRowView: View {
    let conversation: Conversation
    let currentUserId: String
    
    var otherParticipant: ChatParticipant? {
        conversation.otherParticipant(currentUserId: currentUserId)
    }
    
    var unreadCount: Int {
        conversation.unreadCountForUser(currentUserId)
    }
    
    var body: some View {
        HStack(spacing: KHOITheme.spacing_md) {
            // Profile image with unread badge
            ZStack(alignment: .topLeading) {
                Circle()
                    .fill(KHOIColors.chipBackground)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(otherParticipant?.fullName.prefix(1).uppercased() ?? "?")
                            .font(KHOITheme.title2)
                            .foregroundColor(KHOIColors.mutedText)
                    )
                
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

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer() }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(KHOITheme.body)
                    .foregroundColor(isFromCurrentUser ? .white : KHOIColors.darkText)
                    .padding(.horizontal, KHOITheme.spacing_md)
                    .padding(.vertical, KHOITheme.spacing_sm)
                    .background(
                        isFromCurrentUser ? KHOIColors.accentBrown : KHOIColors.cardBackground
                    )
                    .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_lg))
                
                Text(message.formattedTime)
                    .font(KHOITheme.caption2)
                    .foregroundColor(KHOIColors.mutedText)
            }
            
            if !isFromCurrentUser { Spacer() }
        }
    }
}
