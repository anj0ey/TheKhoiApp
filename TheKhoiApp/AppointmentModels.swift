//
//  AppointmentModels.swift
//  TheKhoiApp
//
//  Created by Anjo on 12/2/25.
//

import Foundation
import FirebaseFirestore

// MARK: - Appointment Status
enum AppointmentStatus: String, Codable, CaseIterable {
    case upcoming = "Upcoming"
    case completed = "Completed"
    case cancelled = "Cancelled"
    
    var color: String {
        switch self {
        case .upcoming: return "8B7355" // Accent Brown
        case .completed: return "4CAF50" // Green
        case .cancelled: return "E57373" // Red
        }
    }
}

// MARK: - Appointment Model
struct Appointment: Identifiable, Codable {
    var id: String
    let userId: String
    let serviceType: String // Maps to ChatTag raw values (e.g., "Nails", "Skin")
    let date: Date
    var status: AppointmentStatus
    var notes: String
    let createdAt: Date
    
    // Optional: If you expand to specific providers later
    var providerName: String?
    
    init(id: String = UUID().uuidString,
         userId: String,
         serviceType: String,
         date: Date,
         status: AppointmentStatus = .upcoming,
         notes: String = "",
         createdAt: Date = Date(),
         providerName: String? = nil) {
        self.id = id
        self.userId = userId
        self.serviceType = serviceType
        self.date = date
        self.status = status
        self.notes = notes
        self.createdAt = createdAt
        self.providerName = providerName
    }
}

// MARK: - Firestore Conversion
extension Appointment {
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.userId = data["userId"] as? String ?? ""
        self.serviceType = data["serviceType"] as? String ?? "General"
        self.date = (data["date"] as? Timestamp)?.dateValue() ?? Date()
        
        let statusString = data["status"] as? String ?? "Upcoming"
        self.status = AppointmentStatus(rawValue: statusString) ?? .upcoming
        
        self.notes = data["notes"] as? String ?? ""
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.providerName = data["providerName"] as? String
    }
    
    func toFirestoreData() -> [String: Any] {
        return [
            "userId": userId,
            "serviceType": serviceType,
            "date": Timestamp(date: date),
            "status": status.rawValue,
            "notes": notes,
            "createdAt": Timestamp(date: createdAt),
            "providerName": providerName ?? ""
        ]
    }
}

