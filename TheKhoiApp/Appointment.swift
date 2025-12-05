//
//  Appointment.swift
//  TheKhoiApp
//
//  Created by Anjo on 12/4/25.
//

import Foundation
import FirebaseFirestore

enum AppointmentStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case confirmed = "Confirmed"
    case completed = "Completed"
    case cancelled = "Cancelled"
    case declined = "Declined"
    
    var color: String {
        switch self {
        case .pending: return "FFA726"   // Orange
        case .confirmed: return "66BB6A" // Green
        case .completed: return "29B6F6" // Blue
        case .cancelled, .declined: return "EF5350" // Red
        }
    }
}

struct Appointment: Identifiable, Codable {
    @DocumentID var id: String?
    let clientID: String
    let clientName: String
    let artistID: String
    let artistName: String
    let serviceName: String
    let price: Double
    let date: Date
    var status: AppointmentStatus
    let createdAt: Date
    
    // Helper to format time for UI
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    // Helper to format date for UI
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}
