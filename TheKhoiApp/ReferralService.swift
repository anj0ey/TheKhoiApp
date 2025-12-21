//
//  ReferralService.swift
//  TheKhoiApp
//
//  Service for managing artist referrals
//

import Foundation
import FirebaseFirestore

// MARK: - Referral Model
struct Referral: Identifiable, Codable {
    let id: String
    let referrerId: String          // User who made the referral
    let referrerName: String
    let recipientId: String         // Friend who received the referral
    let recipientName: String
    let artistId: String            // Artist being referred
    let artistName: String
    let artistUsername: String
    let artistProfileImageURL: String?
    let createdAt: Date
    
    init(
        id: String = UUID().uuidString,
        referrerId: String,
        referrerName: String,
        recipientId: String,
        recipientName: String,
        artistId: String,
        artistName: String,
        artistUsername: String,
        artistProfileImageURL: String?,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.referrerId = referrerId
        self.referrerName = referrerName
        self.recipientId = recipientId
        self.recipientName = recipientName
        self.artistId = artistId
        self.artistName = artistName
        self.artistUsername = artistUsername
        self.artistProfileImageURL = artistProfileImageURL
        self.createdAt = createdAt
    }
}

// MARK: - Referral Service
class ReferralService: ObservableObject {
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    
    // MARK: - Send Referral
    
    /// Send a referral to a friend via chat message
    func sendReferral(
        referrer: (id: String, name: String, username: String),
        recipient: Friend,
        artist: Artist,
        chatService: ChatService,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        isLoading = true
        
        // 1. Create or get conversation with friend
        chatService.getOrCreateConversation(
            currentUser: (uid: referrer.id, username: referrer.username, fullName: referrer.name),
            otherUser: (uid: recipient.id, username: recipient.username, fullName: recipient.fullName),
            tag: .friend
        ) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let conversationId):
                // 2. Send referral message
                self.sendReferralMessage(
                    conversationId: conversationId,
                    referrer: referrer,
                    recipient: recipient,
                    artist: artist
                ) { messageResult in
                    switch messageResult {
                    case .success:
                        // 3. Increment artist's referral count
                        self.incrementReferralCount(artistId: artist.id) { _ in
                            // 4. Record the referral
                            self.recordReferral(
                                referrer: referrer,
                                recipient: recipient,
                                artist: artist
                            ) { _ in
                                self.isLoading = false
                                completion(.success(()))
                            }
                        }
                    case .failure(let error):
                        self.isLoading = false
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                self.isLoading = false
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Send Referral Message
    
    private func sendReferralMessage(
        conversationId: String,
        referrer: (id: String, name: String, username: String),
        recipient: Friend,
        artist: Artist,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Create referral message data
        let messageData: [String: Any] = [
            "conversationId": conversationId,
            "senderId": referrer.id,
            "senderName": referrer.name,
            "text": "Check out this artist I found!",
            "timestamp": Timestamp(date: Date()),
            "isRead": false,
            "messageType": "referral",
            "referralData": [
                "artistId": artist.id,
                "artistName": artist.fullName,
                "artistUsername": artist.username,
                "artistProfileImageURL": artist.profileImageURL ?? "",
                "artistCity": artist.city,
                "artistRating": artist.rating ?? 5.0,
                "artistServices": artist.servicesDetailed.prefix(3).map { $0.name }
            ]
        ]
        
        let batch = db.batch()
        
        // Add message
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document()
        batch.setData(messageData, forDocument: messageRef)
        
        // Update conversation
        let conversationRef = db.collection("conversations").document(conversationId)
        batch.updateData([
            "lastMessage": "Sent you an artist recommendation",
            "lastMessageTimestamp": Timestamp(date: Date()),
            "lastSenderId": referrer.id,
            "unreadCount.\(recipient.id)": FieldValue.increment(Int64(1))
        ], forDocument: conversationRef)
        
        batch.commit { error in
            if let error = error {
                completion(.failure(error))
            } else {
                // Send push notification
                NotificationService.shared.sendNewMessageNotification(
                    recipientId: recipient.id,
                    senderName: referrer.name,
                    messagePreview: "Sent you an artist recommendation: \(artist.fullName)",
                    conversationId: conversationId
                )
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Increment Referral Count
    
    private func incrementReferralCount(artistId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("artists").document(artistId).updateData([
            "referralCount": FieldValue.increment(Int64(1))
        ]) { error in
            if let error = error {
                // Try users collection if not in artists
                self.db.collection("users").document(artistId).updateData([
                    "referralCount": FieldValue.increment(Int64(1))
                ]) { error2 in
                    if let error2 = error2 {
                        completion(.failure(error2))
                    } else {
                        completion(.success(()))
                    }
                }
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Record Referral
    
    private func recordReferral(
        referrer: (id: String, name: String, username: String),
        recipient: Friend,
        artist: Artist,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let referralData: [String: Any] = [
            "referrerId": referrer.id,
            "referrerName": referrer.name,
            "recipientId": recipient.id,
            "recipientName": recipient.fullName,
            "artistId": artist.id,
            "artistName": artist.fullName,
            "artistUsername": artist.username,
            "createdAt": Timestamp(date: Date())
        ]
        
        db.collection("referrals").addDocument(data: referralData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Check if Already Referred
    
    func hasAlreadyReferred(
        referrerId: String,
        recipientId: String,
        artistId: String,
        completion: @escaping (Bool) -> Void
    ) {
        db.collection("referrals")
            .whereField("referrerId", isEqualTo: referrerId)
            .whereField("recipientId", isEqualTo: recipientId)
            .whereField("artistId", isEqualTo: artistId)
            .getDocuments { snapshot, error in
                completion(!(snapshot?.documents.isEmpty ?? true))
            }
    }
}
