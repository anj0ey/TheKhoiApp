//
//  ChatService.swift
//  TheKhoiApp
//
//  Handles all chat-related Firestore operations with push notifications
//

import Foundation
import FirebaseFirestore
import Combine

class ChatService: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var currentMessages: [Message] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private var conversationsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    
    // MARK: - Conversations
    
    /// Listen to all conversations for a user
    func listenToConversations(userId: String) {
        conversationsListener?.remove()
        isLoading = true
        
        conversationsListener = db.collection("conversations")
            .whereField("participantIds", arrayContains: userId)
            .order(by: "lastMessageTimestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    print("Error listening to conversations: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self.conversations = documents.compactMap { Conversation(document: $0) }
            }
    }
    
    /// Create a new conversation or return existing one
    /// UPDATED: Now includes profileImageURL parameters
    func getOrCreateConversation(
        currentUser: (uid: String, username: String, fullName: String, profileImageURL: String?),
        otherUser: (uid: String, username: String, fullName: String, profileImageURL: String?),
        tag: ChatTag? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Check if conversation already exists
        let participantIds = [currentUser.uid, otherUser.uid].sorted()
        
        db.collection("conversations")
            .whereField("participantIds", isEqualTo: participantIds)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                // Return existing conversation (and update profile images if needed)
                if let existingDoc = snapshot?.documents.first {
                    // Update profile images in case they changed
                    self.updateParticipantProfileImages(
                        conversationId: existingDoc.documentID,
                        currentUser: currentUser,
                        otherUser: otherUser
                    )
                    completion(.success(existingDoc.documentID))
                    return
                }
                
                // Create new conversation with profile images
                let participants: [String: ChatParticipant] = [
                    currentUser.uid: ChatParticipant(
                        odUid: currentUser.uid,
                        username: currentUser.username,
                        fullName: currentUser.fullName,
                        profileImageURL: currentUser.profileImageURL
                    ),
                    otherUser.uid: ChatParticipant(
                        odUid: otherUser.uid,
                        username: otherUser.username,
                        fullName: otherUser.fullName,
                        profileImageURL: otherUser.profileImageURL
                    )
                ]
                
                let conversation = Conversation(
                    id: UUID().uuidString,
                    participantIds: participantIds,
                    participants: participants,
                    lastMessage: "",
                    lastMessageTimestamp: Date(),
                    lastSenderId: "",
                    unreadCount: [currentUser.uid: 0, otherUser.uid: 0],
                    tag: tag,
                    createdAt: Date()
                )
                
                let docRef = self.db.collection("conversations").document()
                docRef.setData(conversation.toFirestoreData()) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(docRef.documentID))
                    }
                }
            }
    }
    
    /// LEGACY: Backward compatible version without profile images
    /// This will fetch profile images from Firestore
    func getOrCreateConversation(
        currentUser: (uid: String, username: String, fullName: String),
        otherUser: (uid: String, username: String, fullName: String),
        tag: ChatTag? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Fetch profile images for both users first
        fetchProfileImages(for: [currentUser.uid, otherUser.uid]) { [weak self] profileImages in
            let currentUserWithImage = (
                uid: currentUser.uid,
                username: currentUser.username,
                fullName: currentUser.fullName,
                profileImageURL: profileImages[currentUser.uid]
            )
            
            let otherUserWithImage = (
                uid: otherUser.uid,
                username: otherUser.username,
                fullName: otherUser.fullName,
                profileImageURL: profileImages[otherUser.uid]
            )
            
            self?.getOrCreateConversation(
                currentUser: currentUserWithImage as! (uid: String, username: String, fullName: String, profileImageURL: String?),
                otherUser: otherUserWithImage as! (uid: String, username: String, fullName: String, profileImageURL: String?),
                tag: tag,
                completion: completion
            )
        }
    }
    
    /// Fetch profile images for multiple users
    private func fetchProfileImages(for userIds: [String], completion: @escaping ([String: String?]) -> Void) {
        var profileImages: [String: String?] = [:]
        let group = DispatchGroup()
        
        for userId in userIds {
            group.enter()
            
            // Try users collection first
            db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
                guard let self = self else {
                    group.leave()
                    return
                }
                
                if let data = snapshot?.data(),
                   let imageURL = data["profileImageURL"] as? String,
                   !imageURL.isEmpty {
                    profileImages[userId] = imageURL
                    group.leave()
                } else {
                    // Try artists collection as fallback
                    self.db.collection("artists").document(userId).getDocument { artistSnapshot, _ in
                        if let artistData = artistSnapshot?.data(),
                           let imageURL = artistData["profileImageURL"] as? String,
                           !imageURL.isEmpty {
                            profileImages[userId] = imageURL
                        } else {
                            profileImages[userId] = nil
                        }
                        group.leave()
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(profileImages)
        }
    }
    
    /// Update profile images for existing conversation participants
    private func updateParticipantProfileImages(
        conversationId: String,
        currentUser: (uid: String, username: String, fullName: String, profileImageURL: String?),
        otherUser: (uid: String, username: String, fullName: String, profileImageURL: String?)
    ) {
        var updateData: [String: Any] = [:]
        
        if let imageURL = currentUser.profileImageURL, !imageURL.isEmpty {
            updateData["participants.\(currentUser.uid).profileImageURL"] = imageURL
        }
        
        if let imageURL = otherUser.profileImageURL, !imageURL.isEmpty {
            updateData["participants.\(otherUser.uid).profileImageURL"] = imageURL
        }
        
        if !updateData.isEmpty {
            db.collection("conversations").document(conversationId).updateData(updateData) { error in
                if let error = error {
                    print("Error updating participant profile images: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Update a single participant's profile image in all their conversations
    func updateUserProfileImageInConversations(userId: String, newImageURL: String) {
        db.collection("conversations")
            .whereField("participantIds", arrayContains: userId)
            .getDocuments { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                for doc in documents {
                    self?.db.collection("conversations").document(doc.documentID).updateData([
                        "participants.\(userId).profileImageURL": newImageURL
                    ])
                }
            }
    }
    
    // MARK: - Messages
    
    /// Listen to messages in a conversation
    func listenToMessages(conversationId: String) {
        messagesListener?.remove()
        
        messagesListener = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error listening to messages: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self.currentMessages = documents.compactMap { Message(document: $0) }
            }
    }
    
    /// Send a message with push notification
    func sendMessage(
        conversationId: String,
        senderId: String,
        senderName: String,
        text: String,
        otherUserId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        print("ChatService.sendMessage called")
        print("otherUserId: \(otherUserId)")
        
        let message = Message(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: senderId,
            senderName: senderName,
            text: text,
            timestamp: Date(),
            isRead: false
        )
        
        let batch = db.batch()
        
        // Add message to subcollection
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document()
        batch.setData(message.toFirestoreData(), forDocument: messageRef)
        
        // Update conversation with last message
        let conversationRef = db.collection("conversations").document(conversationId)
        batch.updateData([
            "lastMessage": text,
            "lastMessageTimestamp": Timestamp(date: Date()),
            "lastSenderId": senderId,
            "unreadCount.\(otherUserId)": FieldValue.increment(Int64(1))
        ], forDocument: conversationRef)
        
        batch.commit { [weak self] error in
            if let error = error {
                completion(.failure(error))
            } else {
                // Send push notification to recipient
                self?.sendMessageNotification(
                    recipientId: otherUserId,
                    senderName: senderName,
                    messagePreview: text,
                    conversationId: conversationId
                )
                completion(.success(()))
            }
        }
    }
    
    /// Send push notification for new message
    private func sendMessageNotification(
        recipientId: String,
        senderName: String,
        messagePreview: String,
        conversationId: String
    ) {
        print("sendMessageNotification called for: \(recipientId)")
        
        NotificationService.shared.sendNewMessageNotification(
            recipientId: recipientId,
            senderName: senderName,
            messagePreview: messagePreview,
            conversationId: conversationId
        )
    }
    
    /// Mark messages as read
    func markConversationAsRead(conversationId: String, userId: String) {
        db.collection("conversations")
            .document(conversationId)
            .updateData([
                "unreadCount.\(userId)": 0
            ])
    }
    
    /// Get total unread message count for a user
    func getTotalUnreadCount(userId: String, completion: @escaping (Int) -> Void) {
        db.collection("conversations")
            .whereField("participantIds", arrayContains: userId)
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else {
                    completion(0)
                    return
                }
                
                var totalUnread = 0
                for doc in documents {
                    if let unreadCount = doc.data()["unreadCount"] as? [String: Int],
                       let count = unreadCount[userId] {
                        totalUnread += count
                    }
                }
                
                completion(totalUnread)
            }
    }
    
    // MARK: - Fix Existing Conversations (One-time migration)
    
    /// Call this once to fix profile images in existing conversations
    func migrateExistingConversationsWithProfileImages(completion: @escaping (Int) -> Void) {
        db.collection("conversations").getDocuments { [weak self] snapshot, error in
            guard let self = self, let documents = snapshot?.documents else {
                completion(0)
                return
            }
            
            var updatedCount = 0
            let group = DispatchGroup()
            
            for doc in documents {
                let data = doc.data()
                guard let participantIds = data["participantIds"] as? [String] else { continue }
                
                group.enter()
                
                self.fetchProfileImages(for: participantIds) { profileImages in
                    var updateData: [String: Any] = [:]
                    
                    for (userId, imageURL) in profileImages {
                        if let url = imageURL, !url.isEmpty {
                            updateData["participants.\(userId).profileImageURL"] = url
                        }
                    }
                    
                    if !updateData.isEmpty {
                        self.db.collection("conversations").document(doc.documentID).updateData(updateData) { error in
                            if error == nil {
                                updatedCount += 1
                            }
                            group.leave()
                        }
                    } else {
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .main) {
                print("Migration complete. Updated \(updatedCount) conversations.")
                completion(updatedCount)
            }
        }
    }
    
    // MARK: - Cleanup
    
    func stopListening() {
        conversationsListener?.remove()
        messagesListener?.remove()
    }
    
    deinit {
        stopListening()
    }
}
