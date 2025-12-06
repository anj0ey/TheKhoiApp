//
//  ArtistModels.swift
//  TheKhoiApp
//
//  Data models for artists and posts
//

import Foundation
import FirebaseFirestore

// MARK: - Artist Profile (Claimable)
struct Artist: Identifiable, Codable {
    let id: String
    var fullName: String
    var username: String
    var bio: String
    var profileImageURL: String?
    var coverImageURL: String?      // Cover photo for profile
    var services: [String]          // ["Makeup", "Lashes", "Brows"]
    var servicesDetailed: [ServiceItem]? // ADDED: Detailed service info
    var city: String
    var instagram: String?
    var website: String?
    var phoneNumber: String?
    var claimed: Bool
    var claimedBy: String?          // Firebase UID of user who claimed
    var claimedAt: Date?
    var featured: Bool              // Show in discover feed
    var referralCount: Int          // Number of referrals
    var reviewCount: Int            // Number of reviews
    var rating: Double?             // Average rating (1-5)
    var createdAt: Date
    
    // Computed property for display handle
    var displayHandle: String {
        if let instagram = instagram, !instagram.isEmpty {
            return instagram.hasPrefix("@") ? instagram : "@\(instagram)"
        }
        return "@\(username)"
    }
    
    // Default initializer with sensible defaults
    init(
        id: String,
        fullName: String,
        username: String,
        bio: String = "",
        profileImageURL: String? = nil,
        coverImageURL: String? = nil,
        services: [String] = [],
        servicesDetailed: [ServiceItem]? = nil,
        city: String = "",
        instagram: String? = nil,
        website: String? = nil,
        phoneNumber: String? = nil,
        claimed: Bool = false,
        claimedBy: String? = nil,
        claimedAt: Date? = nil,
        featured: Bool = false,
        referralCount: Int = 0,
        reviewCount: Int = 0,
        rating: Double? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.fullName = fullName
        self.username = username
        self.bio = bio
        self.profileImageURL = profileImageURL
        self.coverImageURL = coverImageURL
        self.services = services
        self.servicesDetailed = servicesDetailed
        self.city = city
        self.instagram = instagram
        self.website = website
        self.phoneNumber = phoneNumber
        self.claimed = claimed
        self.claimedBy = claimedBy
        self.claimedAt = claimedAt
        self.featured = featured
        self.referralCount = referralCount
        self.reviewCount = reviewCount
        self.rating = rating
        self.createdAt = createdAt
    }
}

// MARK: - Post (Feed Content)
struct Post: Identifiable, Codable {
    let id: String
    let artistId: String
    var artistName: String
    var artistHandle: String
    var artistProfileImageURL: String?
    var imageURL: String
    var imageHeight: CGFloat        // For masonry layout
    var tag: String                 // Service category
    var caption: String?
    var saveCount: Int
    var createdAt: Date
}

// MARK: - Claim Request
struct ClaimRequest: Identifiable, Codable {
    let id: String
    let artistId: String
    let userId: String
    let userEmail: String
    let userName: String
    let verificationNote: String    // Why they should be verified
    let instagramHandle: String?
    let status: ClaimStatus
    let createdAt: Date
    let reviewedAt: Date?
    let reviewedBy: String?
    let rejectionReason: String?
    
    enum ClaimStatus: String, Codable {
        case pending = "pending"
        case approved = "approved"
        case rejected = "rejected"
    }
}

// MARK: - Firestore Extensions

extension Artist {
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.fullName = data["fullName"] as? String ?? ""
        self.username = data["username"] as? String ?? ""
        self.bio = data["bio"] as? String ?? ""
        self.profileImageURL = data["profileImageURL"] as? String
        self.coverImageURL = data["coverImageURL"] as? String
        self.services = data["services"] as? [String] ?? []
        
        // ADDED: Parse servicesDetailed
        if let servicesData = data["servicesDetailed"] as? [[String: Any]] {
            self.servicesDetailed = servicesData.map { ServiceItem.fromFirestore($0) }
        } else {
            self.servicesDetailed = nil
        }
        
        self.city = data["city"] as? String ?? ""
        self.instagram = data["instagram"] as? String
        self.website = data["website"] as? String
        self.phoneNumber = data["phoneNumber"] as? String
        self.claimed = data["claimed"] as? Bool ?? false
        self.claimedBy = data["claimedBy"] as? String
        self.claimedAt = (data["claimedAt"] as? Timestamp)?.dateValue()
        self.featured = data["featured"] as? Bool ?? false
        self.referralCount = data["referralCount"] as? Int ?? 0
        self.reviewCount = data["reviewCount"] as? Int ?? 0
        self.rating = data["rating"] as? Double
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }
    
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "fullName": fullName,
            "username": username,
            "bio": bio,
            "services": services,
            "city": city,
            "claimed": claimed,
            "featured": featured,
            "referralCount": referralCount,
            "reviewCount": reviewCount,
            "createdAt": Timestamp(date: createdAt)
        ]
        
        if let profileImageURL = profileImageURL {
            data["profileImageURL"] = profileImageURL
        }
        if let coverImageURL = coverImageURL {
            data["coverImageURL"] = coverImageURL
        }
        if let servicesDetailed = servicesDetailed {
            data["servicesDetailed"] = servicesDetailed.map { $0.toFirestoreData() }
        }
        if let instagram = instagram {
            data["instagram"] = instagram
        }
        if let website = website {
            data["website"] = website
        }
        if let phoneNumber = phoneNumber {
            data["phoneNumber"] = phoneNumber
        }
        if let claimedBy = claimedBy {
            data["claimedBy"] = claimedBy
        }
        if let claimedAt = claimedAt {
            data["claimedAt"] = Timestamp(date: claimedAt)
        }
        if let rating = rating {
            data["rating"] = rating
        }
        
        return data
    }
}

extension Post {
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.artistId = data["artistId"] as? String ?? ""
        self.artistName = data["artistName"] as? String ?? ""
        self.artistHandle = data["artistHandle"] as? String ?? ""
        self.artistProfileImageURL = data["artistProfileImageURL"] as? String
        self.imageURL = data["imageURL"] as? String ?? ""
        self.imageHeight = data["imageHeight"] as? CGFloat ?? 280
        self.tag = data["tag"] as? String ?? ""
        self.caption = data["caption"] as? String
        self.saveCount = data["saveCount"] as? Int ?? 0
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }
    
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "artistId": artistId,
            "artistName": artistName,
            "artistHandle": artistHandle,
            "imageURL": imageURL,
            "imageHeight": imageHeight,
            "tag": tag,
            "saveCount": saveCount,
            "createdAt": Timestamp(date: createdAt)
        ]
        
        if let artistProfileImageURL = artistProfileImageURL {
            data["artistProfileImageURL"] = artistProfileImageURL
        }
        if let caption = caption {
            data["caption"] = caption
        }
        
        return data
    }
}

extension ClaimRequest {
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.artistId = data["artistId"] as? String ?? ""
        self.userId = data["userId"] as? String ?? ""
        self.userEmail = data["userEmail"] as? String ?? ""
        self.userName = data["userName"] as? String ?? ""
        self.verificationNote = data["verificationNote"] as? String ?? ""
        self.instagramHandle = data["instagramHandle"] as? String
        self.status = ClaimStatus(rawValue: data["status"] as? String ?? "pending") ?? .pending
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.reviewedAt = (data["reviewedAt"] as? Timestamp)?.dateValue()
        self.reviewedBy = data["reviewedBy"] as? String
        self.rejectionReason = data["rejectionReason"] as? String
    }
    
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "artistId": artistId,
            "userId": userId,
            "userEmail": userEmail,
            "userName": userName,
            "verificationNote": verificationNote,
            "status": status.rawValue,
            "createdAt": Timestamp(date: createdAt)
        ]
        
        if let instagramHandle = instagramHandle {
            data["instagramHandle"] = instagramHandle
        }
        if let reviewedAt = reviewedAt {
            data["reviewedAt"] = Timestamp(date: reviewedAt)
        }
        if let reviewedBy = reviewedBy {
            data["reviewedBy"] = reviewedBy
        }
        if let rejectionReason = rejectionReason {
            data["rejectionReason"] = rejectionReason
        }
        
        return data
    }
}
