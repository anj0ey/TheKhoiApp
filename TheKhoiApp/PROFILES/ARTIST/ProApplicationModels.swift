//
//  ProApplicationModels.swift
//  TheKhoiApp
//
//

import Foundation
import FirebaseFirestore

// MARK: - Service Item
struct ServiceItem: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var name: String = ""
    var category: String = "Makeup"
    var description: String = ""
    var duration: Int = 60  // minutes
    var price: Double = 0
    
    var isValid: Bool {
        !name.isEmpty && price > 0 && duration > 0
    }
    
    func toFirestoreData() -> [String: Any] {
        return [
            "id": id,
            "name": name,
            "category": category,
            "description": description,
            "duration": duration,
            "price": price
        ]
    }
    
    static func fromFirestore(_ data: [String: Any]) -> ServiceItem {
        return ServiceItem(
            id: data["id"] as? String ?? UUID().uuidString,
            name: data["name"] as? String ?? "",
            category: data["category"] as? String ?? "Makeup",
            description: data["description"] as? String ?? "",
            duration: data["duration"] as? Int ?? 60,
            price: data["price"] as? Double ?? 0
        )
    }
}

// MARK: - Business Policies
struct BusinessPolicies: Codable {
    var cancellationPolicy: String = ""
    var depositRequired: Bool = false
    var depositAmount: Double = 0
    var advanceBookingDays: Int = 1
    var lateArrivalPolicy: String = ""
    var additionalNotes: String = ""
    
    func toFirestoreData() -> [String: Any] {
        return [
            "cancellationPolicy": cancellationPolicy,
            "depositRequired": depositRequired,
            "depositAmount": depositAmount,
            "advanceBookingDays": advanceBookingDays,
            "lateArrivalPolicy": lateArrivalPolicy,
            "additionalNotes": additionalNotes
        ]
    }
    
    static func fromFirestore(_ data: [String: Any]) -> BusinessPolicies {
        return BusinessPolicies(
            cancellationPolicy: data["cancellationPolicy"] as? String ?? "",
            depositRequired: data["depositRequired"] as? Bool ?? false,
            depositAmount: data["depositAmount"] as? Double ?? 0,
            advanceBookingDays: data["advanceBookingDays"] as? Int ?? 1,
            lateArrivalPolicy: data["lateArrivalPolicy"] as? String ?? "",
            additionalNotes: data["additionalNotes"] as? String ?? ""
        )
    }
}

// MARK: - Portfolio Image
struct PortfolioImage: Identifiable, Codable {
    var id: String = UUID().uuidString
    var url: String
    var serviceCategory: String
    var uploadedAt: Date = Date()
    
    func toFirestoreData() -> [String: Any] {
        return [
            "id": id,
            "url": url,
            "serviceCategory": serviceCategory,
            "uploadedAt": Timestamp(date: uploadedAt)
        ]
    }
    
    static func fromFirestore(_ data: [String: Any]) -> PortfolioImage {
        return PortfolioImage(
            id: data["id"] as? String ?? UUID().uuidString,
            url: data["url"] as? String ?? "",
            serviceCategory: data["serviceCategory"] as? String ?? "",
            uploadedAt: (data["uploadedAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
}

// MARK: - Application Status
enum ApplicationStatus: String, Codable {
    case draft = "draft"
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
}

// MARK: - Business Proof Type
enum BusinessProofType: String, Codable, CaseIterable {
    case instagram = "instagram"
    case googleBusiness = "google_business"
    case yelp = "yelp"
    case website = "website"
    case businessCard = "business_card"
    
    var displayName: String {
        switch self {
        case .instagram: return "Instagram"
        case .googleBusiness: return "Google Business"
        case .yelp: return "Yelp"
        case .website: return "Website"
        case .businessCard: return "Business Card"
        }
    }
    
    var icon: String {
        switch self {
        case .instagram: return "camera"
        case .googleBusiness: return "building.2"
        case .yelp: return "star.bubble"
        case .website: return "globe"
        case .businessCard: return "rectangle.on.rectangle"
        }
    }
}

// MARK: - Pro Application
struct ProApplication: Identifiable, Codable {
    var id: String = UUID().uuidString
    var userId: String
    var userEmail: String
    var status: ApplicationStatus = .draft
    var submittedAt: Date?
    var reviewedAt: Date?
    var reviewedBy: String?
    var rejectionReason: String?
    
    // Step 1: Basic Info
    var businessName: String = ""
    var location: String = ""
    var bio: String = ""
    
    // Step 2: Services
    var services: [ServiceItem] = []
    
    // Step 3: Policies
    var policies: BusinessPolicies = BusinessPolicies()
    
    // Step 4: Portfolio
    var portfolioImages: [PortfolioImage] = []
    
    // Step 5: Availability (NEW)
    var availability: BusinessAvailability = BusinessAvailability()
    
    // Step 6: Verification
    var instagramHandle: String = ""
    var businessProofURL: String?
    var businessProofType: BusinessProofType?
    
    // Validation
    var isStep1Valid: Bool {
        !businessName.isEmpty && !location.isEmpty && !bio.isEmpty
    }
    
    var isStep2Valid: Bool {
        !services.isEmpty && services.allSatisfy { $0.isValid }
    }
    
    var isStep3Valid: Bool {
        true // Policies are optional
    }
    
    var isStep4Valid: Bool {
        // Need at least 2 portfolio images per service category
        let categories = Set(services.map { $0.category })
        for category in categories {
            let imagesForCategory = portfolioImages.filter { $0.serviceCategory == category }
            if imagesForCategory.count < 2 {
                return false
            }
        }
        return !portfolioImages.isEmpty
    }
    
    var isStep5Valid: Bool {
        // At least one day must be open
        availability.allDays.contains { $0.availability.isOpen }
    }
    
    var isStep6Valid: Bool {
        !instagramHandle.isEmpty || businessProofURL != nil
    }
    
    var isReadyToSubmit: Bool {
        isStep1Valid && isStep2Valid && isStep4Valid && isStep5Valid && isStep6Valid
    }
    
    // Get unique service categories
    var serviceCategories: [String] {
        Array(Set(services.map { $0.category })).sorted()
    }
    
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "userEmail": userEmail,
            "status": status.rawValue,
            "businessName": businessName,
            "location": location,
            "bio": bio,
            "services": services.map { $0.toFirestoreData() },
            "policies": policies.toFirestoreData(),
            "portfolioImages": portfolioImages.map { $0.toFirestoreData() },
            "availability": availability.toFirestoreData(),
            "instagramHandle": instagramHandle
        ]
        
        if let submittedAt = submittedAt {
            data["submittedAt"] = Timestamp(date: submittedAt)
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
        if let businessProofURL = businessProofURL {
            data["businessProofURL"] = businessProofURL
        }
        if let businessProofType = businessProofType {
            data["businessProofType"] = businessProofType.rawValue
        }
        
        return data
    }
    
    static func fromFirestore(document: DocumentSnapshot) -> ProApplication? {
        guard let data = document.data() else { return nil }
        
        var app = ProApplication(
            id: document.documentID,
            userId: data["userId"] as? String ?? "",
            userEmail: data["userEmail"] as? String ?? ""
        )
        
        app.status = ApplicationStatus(rawValue: data["status"] as? String ?? "draft") ?? .draft
        app.submittedAt = (data["submittedAt"] as? Timestamp)?.dateValue()
        app.reviewedAt = (data["reviewedAt"] as? Timestamp)?.dateValue()
        app.reviewedBy = data["reviewedBy"] as? String
        app.rejectionReason = data["rejectionReason"] as? String
        
        app.businessName = data["businessName"] as? String ?? ""
        app.location = data["location"] as? String ?? ""
        app.bio = data["bio"] as? String ?? ""
        
        if let servicesData = data["services"] as? [[String: Any]] {
            app.services = servicesData.map { ServiceItem.fromFirestore($0) }
        }
        
        if let policiesData = data["policies"] as? [String: Any] {
            app.policies = BusinessPolicies.fromFirestore(policiesData)
        }
        
        if let portfolioData = data["portfolioImages"] as? [[String: Any]] {
            app.portfolioImages = portfolioData.map { PortfolioImage.fromFirestore($0) }
        }
        
        if let availabilityData = data["availability"] as? [String: Any] {
            app.availability = BusinessAvailability.fromFirestore(availabilityData)
        }
        
        app.instagramHandle = data["instagramHandle"] as? String ?? ""
        app.businessProofURL = data["businessProofURL"] as? String
        if let proofType = data["businessProofType"] as? String {
            app.businessProofType = BusinessProofType(rawValue: proofType)
        }
        
        return app
    }
}

// MARK: - Service Categories
struct ServiceCategories {
    static let all = ["Makeup", "Hair", "Nails", "Lashes", "Brows", "Skin", "Body"]
    
    static func color(for category: String) -> String {
        switch category {
        case "Makeup": return "E91E63"
        case "Hair": return "009688"
        case "Nails": return "9C27B0"
        case "Lashes": return "3F51B5"
        case "Brows": return "795548"
        case "Skin": return "FF5722"
        case "Body": return "607D8B"
        default: return "9E9E9E"
        }
    }
}
