//
//  ChatModels.swift
//  TheKhoiApp
//
//  Chat data models with referral support
//

import Foundation
import FirebaseFirestore

// MARK: - Message Type
enum MessageType: String, Codable {
    case text = "text"
    case referral = "referral"
    case image = "image"
}

// MARK: - Referral Data (embedded in referral messages)
struct ReferralMessageData: Codable {
    let artistId: String
    let artistName: String
    let artistUsername: String
    let artistProfileImageURL: String?
    let artistCity: String
    let artistRating: Double
    let artistServices: [String]
    
    init(
        artistId: String,
        artistName: String,
        artistUsername: String,
        artistProfileImageURL: String?,
        artistCity: String,
        artistRating: Double,
        artistServices: [String]
    ) {
        self.artistId = artistId
        self.artistName = artistName
        self.artistUsername = artistUsername
        self.artistProfileImageURL = artistProfileImageURL
        self.artistCity = artistCity
        self.artistRating = artistRating
        self.artistServices = artistServices
    }
    
    init?(data: [String: Any]) {
        guard let artistId = data["artistId"] as? String,
              let artistName = data["artistName"] as? String,
              let artistUsername = data["artistUsername"] as? String else {
            return nil
        }
        
        self.artistId = artistId
        self.artistName = artistName
        self.artistUsername = artistUsername
        self.artistProfileImageURL = data["artistProfileImageURL"] as? String
        self.artistCity = data["artistCity"] as? String ?? ""
        self.artistRating = data["artistRating"] as? Double ?? 5.0
        self.artistServices = data["artistServices"] as? [String] ?? []
    }
    
    var displayHandle: String {
        return artistUsername.hasPrefix("@") ? artistUsername : "@\(artistUsername)"
    }
}

// MARK: - Chat Tag (service type or relationship)
enum ChatTag: String, CaseIterable, Codable {
    case friend = "Friend"
    case makeup = "Makeup"
    case skin = "Skin"
    case nails = "Nails"
    case lashes = "Lashes"
    case hair = "Hair"
    case brows = "Brows"
    case body = "Body"
    
    var color: String {
        switch self {
        case .friend: return "4CAF50"  // Green
        case .makeup: return "E91E63"  // Pink
        case .skin: return "FF5722"    // Deep Orange
        case .nails: return "9C27B0"   // Purple
        case .lashes: return "3F51B5"  // Indigo
        case .hair: return "009688"    // Teal
        case .brows: return "795548"   // Brown
        case .body: return "607D8B"    // Blue Grey
        }
    }
}

// MARK: - Chat Participant
struct ChatParticipant: Codable, Identifiable {
    var id: String { odUid }
    let odUid: String
    let username: String
    let fullName: String
    let profileImageURL: String?
}

// MARK: - Conversation (Chat Thread)
struct Conversation: Identifiable, Codable {
    let id: String
    let participantIds: [String]
    let participants: [String: ChatParticipant]
    let lastMessage: String
    let lastMessageTimestamp: Date
    let lastSenderId: String
    let unreadCount: [String: Int]
    let tag: ChatTag?
    let createdAt: Date
    
    // Get the other participant (not the current user)
    func otherParticipant(currentUserId: String) -> ChatParticipant? {
        return participants.values.first { $0.odUid != currentUserId }
    }
    
    // Get unread count for current user
    func unreadCountForUser(_ userId: String) -> Int {
        return unreadCount[userId] ?? 0
    }
    
    // Format timestamp for display
    var formattedTimestamp: String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfYear], from: lastMessageTimestamp, to: now)
        
        if let weeks = components.weekOfYear, weeks >= 4 {
            let months = weeks / 4
            return "\(months)mo ago"
        } else if let weeks = components.weekOfYear, weeks >= 1 {
            return "\(weeks)w ago"
        } else if let days = components.day, days >= 1 {
            return "\(days)d ago"
        } else if let hours = components.hour, hours >= 1 {
            return "\(hours)hr ago"
        } else if let minutes = components.minute, minutes >= 1 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - Message (Updated with type support)
struct Message: Identifiable, Codable {
    let id: String
    let conversationId: String
    let senderId: String
    let senderName: String
    let text: String
    let timestamp: Date
    let isRead: Bool
    let messageType: MessageType
    let referralData: ReferralMessageData?
    
    // Convenience initializer for text messages
    init(
        id: String,
        conversationId: String,
        senderId: String,
        senderName: String,
        text: String,
        timestamp: Date,
        isRead: Bool
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.timestamp = timestamp
        self.isRead = isRead
        self.messageType = .text
        self.referralData = nil
    }
    
    // Full initializer
    init(
        id: String,
        conversationId: String,
        senderId: String,
        senderName: String,
        text: String,
        timestamp: Date,
        isRead: Bool,
        messageType: MessageType,
        referralData: ReferralMessageData?
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.timestamp = timestamp
        self.isRead = isRead
        self.messageType = messageType
        self.referralData = referralData
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var isReferral: Bool {
        return messageType == .referral
    }
}

// MARK: - Firestore Extensions
extension Conversation {
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.participantIds = data["participantIds"] as? [String] ?? []
        self.lastMessage = data["lastMessage"] as? String ?? ""
        self.lastSenderId = data["lastSenderId"] as? String ?? ""
        self.unreadCount = data["unreadCount"] as? [String: Int] ?? [:]
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.lastMessageTimestamp = (data["lastMessageTimestamp"] as? Timestamp)?.dateValue() ?? Date()
        
        // Parse tag
        if let tagString = data["tag"] as? String {
            self.tag = ChatTag(rawValue: tagString)
        } else {
            self.tag = nil
        }
        
        // Parse participants
        var parsedParticipants: [String: ChatParticipant] = [:]
        if let participantsData = data["participants"] as? [String: [String: Any]] {
            for (uid, participantData) in participantsData {
                let participant = ChatParticipant(
                    odUid: uid,
                    username: participantData["username"] as? String ?? "",
                    fullName: participantData["fullName"] as? String ?? "",
                    profileImageURL: participantData["profileImageURL"] as? String
                )
                parsedParticipants[uid] = participant
            }
        }
        self.participants = parsedParticipants
    }
    
    func toFirestoreData() -> [String: Any] {
        var participantsData: [String: [String: Any]] = [:]
        for (uid, participant) in participants {
            participantsData[uid] = [
                "username": participant.username,
                "fullName": participant.fullName,
                "profileImageURL": participant.profileImageURL ?? ""
            ]
        }
        
        return [
            "participantIds": participantIds,
            "participants": participantsData,
            "lastMessage": lastMessage,
            "lastMessageTimestamp": Timestamp(date: lastMessageTimestamp),
            "lastSenderId": lastSenderId,
            "unreadCount": unreadCount,
            "tag": tag?.rawValue ?? "",
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}

extension Message {
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.conversationId = data["conversationId"] as? String ?? ""
        self.senderId = data["senderId"] as? String ?? ""
        self.senderName = data["senderName"] as? String ?? ""
        self.text = data["text"] as? String ?? ""
        self.timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        self.isRead = data["isRead"] as? Bool ?? false
        
        // Parse message type
        if let typeString = data["messageType"] as? String,
           let type = MessageType(rawValue: typeString) {
            self.messageType = type
        } else {
            self.messageType = .text
        }
        
        // Parse referral data if present
        if let refData = data["referralData"] as? [String: Any] {
            self.referralData = ReferralMessageData(data: refData)
        } else {
            self.referralData = nil
        }
    }
    
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "conversationId": conversationId,
            "senderId": senderId,
            "senderName": senderName,
            "text": text,
            "timestamp": Timestamp(date: timestamp),
            "isRead": isRead,
            "messageType": messageType.rawValue
        ]
        
        if let refData = referralData {
            data["referralData"] = [
                "artistId": refData.artistId,
                "artistName": refData.artistName,
                "artistUsername": refData.artistUsername,
                "artistProfileImageURL": refData.artistProfileImageURL ?? "",
                "artistCity": refData.artistCity,
                "artistRating": refData.artistRating,
                "artistServices": refData.artistServices
            ]
        }
        
        return data
    }
}
