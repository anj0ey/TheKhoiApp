//
//  CommentModels.swift
//  TheKhoiApp
//
//  Data models for post comments
//

import Foundation
import FirebaseFirestore

// MARK: - Comment Model
struct Comment: Identifiable {
    var id: String = UUID().uuidString
    
    // Comment content
    var text: String
    
    // Author info
    var authorId: String
    var authorName: String
    var authorUsername: String
    var authorProfileImageURL: String?
    
    // Post info
    var postId: String
    
    // Timestamps
    var createdAt: Date
    
    // Computed properties
    var timeAgo: String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day, .weekOfYear], from: createdAt, to: now)
        
        if let weeks = components.weekOfYear, weeks > 0 {
            return "\(weeks)w ago"
        } else if let days = components.day, days > 0 {
            return "\(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)hr ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
    
    // Initialize
    init(
        id: String = UUID().uuidString,
        text: String,
        authorId: String,
        authorName: String,
        authorUsername: String,
        authorProfileImageURL: String? = nil,
        postId: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.authorId = authorId
        self.authorName = authorName
        self.authorUsername = authorUsername
        self.authorProfileImageURL = authorProfileImageURL
        self.postId = postId
        self.createdAt = createdAt
    }
    
    // Firestore conversion
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "text": text,
            "authorId": authorId,
            "authorName": authorName,
            "authorUsername": authorUsername,
            "postId": postId,
            "createdAt": Timestamp(date: createdAt)
        ]
        
        if let authorProfileImageURL = authorProfileImageURL {
            data["authorProfileImageURL"] = authorProfileImageURL
        }
        
        return data
    }
    
    static func fromFirestore(document: DocumentSnapshot) -> Comment? {
        guard let data = document.data() else { return nil }
        
        return Comment(
            id: document.documentID,
            text: data["text"] as? String ?? "",
            authorId: data["authorId"] as? String ?? "",
            authorName: data["authorName"] as? String ?? "",
            authorUsername: data["authorUsername"] as? String ?? "",
            authorProfileImageURL: data["authorProfileImageURL"] as? String,
            postId: data["postId"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
}

// MARK: - Review Summary (for post detail)
struct PostReviewSummary {
    var reviewerAvatars: [String]  // URLs of first few reviewer profile pics
    var totalCount: Int
    
    var displayText: String {
        if totalCount == 0 {
            return "No reviews yet"
        } else if totalCount == 1 {
            return "1 client review"
        } else {
            return "\(totalCount) client reviews"
        }
    }
}
