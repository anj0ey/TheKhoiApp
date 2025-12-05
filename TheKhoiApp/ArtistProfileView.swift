//
//  ArtistProfileView.swift
//  TheKhoiApp
//
//  Updated with message button for chat functionality
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
    
    // Chat State
    @StateObject private var chatService = ChatService()
    @State private var showChat = false
    @State private var activeConversation: Conversation?
    @State private var isCreatingChat = false
    
    // Check if this is the current user's own profile
    private var isOwnProfile: Bool {
        authManager.firebaseUID == artist.id
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            KHOIColors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // 1. Header (Cover + Avatar)
                    headerSection
                    
                    // 2. Info (Name, Bio, Stats)
                    infoSection
                    
                    // 3. Tabs (Posts / Services / Reviews)
                    tabSection
                    
                    // 4. Content Grid
                    if selectedTab == "Posts" {
                        postsGrid
                    } else if selectedTab == "Services" {
                        servicesList
                    } else {
                        Text("No reviews yet.")
                            .foregroundColor(KHOIColors.mutedText)
                            .padding(.top, 40)
                    }
                    
                    // Spacer for the floating buttons
                    Color.clear.frame(height: 120)
                }
            }
            
            // 5. FLOATING BUTTONS (Message + Book)
            if !isOwnProfile {
                floatingButtonsSection
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBookingSheet) {
            BookingSheetView(artist: artist, isPresented: $showBookingSheet)
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
                
                // Book Button
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
            .padding(.horizontal, KHOITheme.spacing_md)
            .padding(.bottom, KHOITheme.spacing_lg)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
        }
    }
    
    // MARK: - Chat Actions
    private func startChat() {
        guard let currentUser = authManager.currentUser,
              let uid = authManager.firebaseUID else { return }
        
        // Don't allow chatting with yourself
        guard uid != artist.id else { return }
        
        isCreatingChat = true
        
        chatService.getOrCreateConversation(
            currentUser: (uid: uid, username: currentUser.username, fullName: currentUser.fullName),
            otherUser: (uid: artist.id, username: artist.username, fullName: artist.fullName),
            tag: nil
        ) { result in
            switch result {
            case .success(let convId):
                // Fetch the full conversation object
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
    
    // MARK: - Components
    
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
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(artist.fullName)
                        .font(KHOITheme.heading2)
                        .foregroundColor(KHOIColors.darkText)
                    
                    Text("@\(artist.username)")
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.mutedText)
                }
                Spacer()
                
                // Save Button (only show if not own profile)
                if !isOwnProfile {
                    HStack(spacing: 12) {
                        Button(action: { isSaved.toggle() }) {
                            Image(systemName: isSaved ? "heart.fill" : "heart")
                                .foregroundColor(isSaved ? KHOIColors.accentBrown : KHOIColors.darkText)
                                .font(.system(size: 20))
                                .padding(10)
                                .background(KHOIColors.cardBackground)
                                .clipShape(Circle())
                        }
                    }
                }
            }
            
            if !artist.bio.isEmpty {
                Text(artist.bio)
                    .font(KHOITheme.body)
                    .foregroundColor(KHOIColors.darkText)
                    .lineLimit(3)
            }
            
            // Stats
            HStack(spacing: 24) {
                statItem(value: "\(artist.referralCount)", label: "Referrals")
                statItem(value: String(format: "%.1f", artist.rating ?? 5.0), label: "Rating")
                if !artist.city.isEmpty {
                    statItem(value: artist.city, label: "Location")
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, KHOITheme.spacing_md)
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
    
    private var tabSection: some View {
        HStack(spacing: 0) {
            tabButton(title: "Posts")
            tabButton(title: "Services")
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
    
    private var postsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 200)
            }
        }
        .padding(KHOITheme.spacing_md)
    }
    
    private var servicesList: some View {
        VStack(spacing: 16) {
            if artist.services.isEmpty {
                Text("No services listed yet.")
                    .foregroundColor(KHOIColors.mutedText)
                    .padding(.top, 40)
            } else {
                ForEach(artist.services, id: \.self) { service in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(service)
                                .font(KHOITheme.body)
                                .bold()
                            Text("1 hr - $80")
                                .font(KHOITheme.caption)
                                .foregroundColor(KHOIColors.mutedText)
                        }
                        Spacer()
                        Button("Book") {
                            showBookingSheet = true
                        }
                        .font(KHOITheme.caption.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(KHOIColors.darkText)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(KHOIColors.cardBackground)
                    .cornerRadius(12)
                }
            }
        }
        .padding(KHOITheme.spacing_md)
    }
}
