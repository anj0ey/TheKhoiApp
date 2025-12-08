//
//  ArtistModels.swift
//  TheKhoiApp
//
//  Data models for artists and posts
//  NOTE: ServiceItem, BusinessPolicies, and PortfolioImage are defined in ProApplicationModels.swift
//

import Foundation
import FirebaseFirestore

// MARK: - Artist Profile (Claimable)
struct Artist: Identifiable {
    let id: String
    var fullName: String
    var username: String
    var bio: String
    
    var profileImageURL: String?
    var coverImageURL: String?
    
    var services: [String]  // Legacy simple service names (deprecated)
    var servicesDetailed: [ServiceItem]  // Full service details from pro application
    var portfolioImages: [PortfolioImage]  // Portfolio images from pro application
    var policies: BusinessPolicies?  // Business policies from pro application
    var city: String
    var instagram: String?
    var website: String?
    var phoneNumber: String?
    var claimed: Bool
    var claimedBy: String?
    var claimedAt: Date?
    var featured: Bool
    var referralCount: Int
    var reviewCount: Int
    var rating: Double?
    var verified: Bool
    var createdAt: Date
    
    var displayHandle: String {
        if let instagram = instagram, !instagram.isEmpty {
            return instagram.hasPrefix("@") ? instagram : "@\(instagram)"
        }
        return "@\(username)"
    }
    
    /// Get portfolio images for a specific service category
    func portfolioImagesForCategory(_ category: String) -> [PortfolioImage] {
        return portfolioImages.filter { $0.serviceCategory == category }
    }
    
    /// Get unique service categories
    var serviceCategories: [String] {
        return Array(Set(servicesDetailed.map { $0.category })).sorted()
    }
    
    /// Check if this artist has real services (filled out by pro)
    var hasDetailedServices: Bool {
        return !servicesDetailed.isEmpty
    }
    
    init(
        id: String,
        fullName: String,
        username: String,
        bio: String = "",
        profileImageURL: String? = nil,
        coverImageURL: String? = nil,
        services: [String] = [],
        servicesDetailed: [ServiceItem] = [],
        portfolioImages: [PortfolioImage] = [],
        policies: BusinessPolicies? = nil,
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
        verified: Bool = false,
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
        self.portfolioImages = portfolioImages
        self.policies = policies
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
        self.verified = verified
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
    var imageHeight: CGFloat
    var tag: String
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
    let verificationNote: String
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
        
        // Parse servicesDetailed - only from pro application data
        if let servicesData = data["servicesDetailed"] as? [[String: Any]] {
            self.servicesDetailed = servicesData.map { ServiceItem.fromFirestore($0) }
        } else {
            self.servicesDetailed = []
        }
        
        // Parse portfolioImages - only from pro application data
        if let portfolioData = data["portfolioImages"] as? [[String: Any]] {
            self.portfolioImages = portfolioData.map { PortfolioImage.fromFirestore($0) }
        } else {
            self.portfolioImages = []
        }
        
        // Parse policies - only from pro application data
        if let policiesData = data["policies"] as? [String: Any] {
            self.policies = BusinessPolicies.fromFirestore(policiesData)
        } else {
            self.policies = nil
        }
        
        self.city = data["city"] as? String ?? data["location"] as? String ?? ""
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
        self.verified = data["verified"] as? Bool ?? false
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }
    
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "fullName": fullName,
            "username": username,
            "bio": bio,
            "services": services,
            "servicesDetailed": servicesDetailed.map { $0.toFirestoreData() },
            "portfolioImages": portfolioImages.map { $0.toFirestoreData() },
            "city": city,
            "claimed": claimed,
            "featured": featured,
            "referralCount": referralCount,
            "reviewCount": reviewCount,
            "verified": verified,
            "createdAt": Timestamp(date: createdAt)
        ]
        
        if let policies = policies {
            data["policies"] = policies.toFirestoreData()
        }
        if let profileImageURL = profileImageURL {
            data["profileImageURL"] = profileImageURL
        }
        if let coverImageURL = coverImageURL {
            data["coverImageURL"] = coverImageURL
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
