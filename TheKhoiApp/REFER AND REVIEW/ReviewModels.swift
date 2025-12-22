//
//  ReviewModels.swift
//  TheKhoiApp
//
//  Data models for the review system
//

import Foundation
import FirebaseFirestore

// MARK: - Review Model
struct Review: Identifiable {
    var id: String = UUID().uuidString
    
    // Review content
    var rating: Int  // 1-5 stars
    var reviewText: String
    var serviceReceived: String  // Service name they got
    var images: [String]  // URLs of uploaded review images
    
    // Author info
    var authorId: String
    var authorName: String
    var authorUsername: String
    var authorProfileImageURL: String?
    var isAnonymous: Bool
    
    // Artist info
    var artistId: String
    var artistName: String
    
    // Related appointment (for verification)
    var appointmentId: String?
    
    // Timestamps
    var createdAt: Date
    var updatedAt: Date?
    
    // Computed properties
    var displayName: String {
        isAnonymous ? "this user chose to be anonymous" : authorName
    }
    
    var displayUsername: String {
        isAnonymous ? "" : "@\(authorUsername)"
    }
    
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
    
    // Initialize with defaults
    init(
        id: String = UUID().uuidString,
        rating: Int,
        reviewText: String,
        serviceReceived: String,
        images: [String] = [],
        authorId: String,
        authorName: String,
        authorUsername: String,
        authorProfileImageURL: String? = nil,
        isAnonymous: Bool = false,
        artistId: String,
        artistName: String,
        appointmentId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.rating = rating
        self.reviewText = reviewText
        self.serviceReceived = serviceReceived
        self.images = images
        self.authorId = authorId
        self.authorName = authorName
        self.authorUsername = authorUsername
        self.authorProfileImageURL = authorProfileImageURL
        self.isAnonymous = isAnonymous
        self.artistId = artistId
        self.artistName = artistName
        self.appointmentId = appointmentId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Firestore conversion
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "rating": rating,
            "reviewText": reviewText,
            "serviceReceived": serviceReceived,
            "images": images,
            "authorId": authorId,
            "authorName": authorName,
            "authorUsername": authorUsername,
            "isAnonymous": isAnonymous,
            "artistId": artistId,
            "artistName": artistName,
            "createdAt": Timestamp(date: createdAt)
        ]
        
        if let authorProfileImageURL = authorProfileImageURL {
            data["authorProfileImageURL"] = authorProfileImageURL
        }
        if let appointmentId = appointmentId {
            data["appointmentId"] = appointmentId
        }
        if let updatedAt = updatedAt {
            data["updatedAt"] = Timestamp(date: updatedAt)
        }
        
        return data
    }
    
    static func fromFirestore(document: DocumentSnapshot) -> Review? {
        guard let data = document.data() else { return nil }
        
        return Review(
            id: document.documentID,
            rating: data["rating"] as? Int ?? 0,
            reviewText: data["reviewText"] as? String ?? "",
            serviceReceived: data["serviceReceived"] as? String ?? "",
            images: data["images"] as? [String] ?? [],
            authorId: data["authorId"] as? String ?? "",
            authorName: data["authorName"] as? String ?? "",
            authorUsername: data["authorUsername"] as? String ?? "",
            authorProfileImageURL: data["authorProfileImageURL"] as? String,
            isAnonymous: data["isAnonymous"] as? Bool ?? false,
            artistId: data["artistId"] as? String ?? "",
            artistName: data["artistName"] as? String ?? "",
            appointmentId: data["appointmentId"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
        )
    }
}

// MARK: - Review Statistics
struct ReviewStats {
    var totalReviews: Int = 0
    var averageRating: Double = 0.0
    var ratingDistribution: [Int: Int] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
    
    var formattedRating: String {
        return String(format: "%.1f", averageRating)
    }
    
    static func calculate(from reviews: [Review]) -> ReviewStats {
        guard !reviews.isEmpty else { return ReviewStats() }
        
        var stats = ReviewStats()
        stats.totalReviews = reviews.count
        
        var totalRating = 0
        for review in reviews {
            totalRating += review.rating
            stats.ratingDistribution[review.rating, default: 0] += 1
        }
        
        stats.averageRating = Double(totalRating) / Double(reviews.count)
        return stats
    }
}

// MARK: - Review Form State
class ReviewFormState: ObservableObject {
    @Published var rating: Int = 0
    @Published var reviewText: String = ""
    @Published var selectedService: String = ""
    @Published var isAnonymous: Bool = false
    @Published var images: [String] = []
    @Published var selectedImages: [UIImage] = []
    
    var isValid: Bool {
        rating > 0 && !reviewText.isEmpty && !selectedService.isEmpty
    }
    
    var characterCount: Int {
        reviewText.count
    }
    
    let maxCharacters = 1000
    
    func reset() {
        rating = 0
        reviewText = ""
        selectedService = ""
        isAnonymous = false
        images = []
        selectedImages = []
    }
}
