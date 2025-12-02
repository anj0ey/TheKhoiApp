//
//  ChatService.swift
//  TheKhoiApp
//
//  Handles all chat-related Firestore operations
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
    func getOrCreateConversation(
        currentUser: (uid: String, username: String, fullName: String),
        otherUser: (uid: String, username: String, fullName: String),
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
                
                // Return existing conversation
                if let existingDoc = snapshot?.documents.first {
                    completion(.success(existingDoc.documentID))
                    return
                }
                
                // Create new conversation
                let participants: [String: ChatParticipant] = [
                    currentUser.uid: ChatParticipant(
                        odUid: currentUser.uid,
                        username: currentUser.username,
                        fullName: currentUser.fullName,
                        profileImageURL: nil
                    ),
                    otherUser.uid: ChatParticipant(
                        odUid: otherUser.uid,
                        username: otherUser.username,
                        fullName: otherUser.fullName,
                        profileImageURL: nil
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
    
    /// Send a message
    func sendMessage(
        conversationId: String,
        senderId: String,
        senderName: String,
        text: String,
        otherUserId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
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
        
        batch.commit { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    /// Mark messages as read
    func markConversationAsRead(conversationId: String, userId: String) {
        db.collection("conversations")
            .document(conversationId)
            .updateData([
                "unreadCount.\(userId)": 0
            ])
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
