//
//  BookingModels.swift
//  TheKhoiApp
//
//  Data models for bookings and appointments
//

import Foundation
import FirebaseFirestore

// MARK: - Appointment Status
enum AppointmentStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case confirmed = "confirmed"
    case completed = "completed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .confirmed: return "Confirmed"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "FF9500"      // Orange
        case .confirmed: return "34C759"    // Green
        case .completed: return "8E8E93"    // Gray
        case .cancelled: return "FF3B30"    // Red
        }
    }
}

// MARK: - Appointment Model
struct Appointment: Identifiable, Codable {
    var id: String = UUID().uuidString
    
    // Client info
    var clientId: String
    var clientName: String
    var clientEmail: String
    var clientPhone: String
    var clientProfileImageURL: String?
    
    // Artist info
    var artistId: String
    var artistName: String
    var artistProfileImageURL: String?
    var artistLocation: String
    
    // Service info
    var serviceId: String
    var serviceName: String
    var serviceCategory: String
    var servicePrice: Double
    var serviceDuration: Int  // minutes
    var serviceDescription: String
    
    // Booking details
    var date: Date
    var timeSlot: String          // e.g., "10:00 AM"
    var endTime: String           // calculated from duration
    var status: AppointmentStatus
    
    // Additional info
    var inspoImages: [String]     // URLs of inspiration images
    var specialRequests: String
    var textNotifications: Bool
    
    // Timestamps
    var createdAt: Date
    var updatedAt: Date?
    var confirmedAt: Date?
    var cancelledAt: Date?
    var cancelReason: String?
    
    // Computed properties
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    
    var formattedShortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    var formattedPrice: String {
        return "$\(Int(servicePrice))"
    }
    
    var formattedDuration: String {
        if serviceDuration >= 60 {
            let hours = serviceDuration / 60
            let mins = serviceDuration % 60
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(mins)min"
        }
        return "\(serviceDuration) min"
    }
    
    // Initialize with defaults
    init(
        id: String = UUID().uuidString,
        clientId: String,
        clientName: String,
        clientEmail: String,
        clientPhone: String = "",
        clientProfileImageURL: String? = nil,
        artistId: String,
        artistName: String,
        artistProfileImageURL: String? = nil,
        artistLocation: String = "",
        serviceId: String,
        serviceName: String,
        serviceCategory: String,
        servicePrice: Double,
        serviceDuration: Int,
        serviceDescription: String = "",
        date: Date,
        timeSlot: String,
        endTime: String = "",
        status: AppointmentStatus = .pending,
        inspoImages: [String] = [],
        specialRequests: String = "",
        textNotifications: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        confirmedAt: Date? = nil,
        cancelledAt: Date? = nil,
        cancelReason: String? = nil
    ) {
        self.id = id
        self.clientId = clientId
        self.clientName = clientName
        self.clientEmail = clientEmail
        self.clientPhone = clientPhone
        self.clientProfileImageURL = clientProfileImageURL
        self.artistId = artistId
        self.artistName = artistName
        self.artistProfileImageURL = artistProfileImageURL
        self.artistLocation = artistLocation
        self.serviceId = serviceId
        self.serviceName = serviceName
        self.serviceCategory = serviceCategory
        self.servicePrice = servicePrice
        self.serviceDuration = serviceDuration
        self.serviceDescription = serviceDescription
        self.date = date
        self.timeSlot = timeSlot
        self.endTime = endTime
        self.status = status
        self.inspoImages = inspoImages
        self.specialRequests = specialRequests
        self.textNotifications = textNotifications
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.confirmedAt = confirmedAt
        self.cancelledAt = cancelledAt
        self.cancelReason = cancelReason
    }
    
    // Firestore conversion
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "clientId": clientId,
            "clientName": clientName,
            "clientEmail": clientEmail,
            "clientPhone": clientPhone,
            "artistId": artistId,
            "artistName": artistName,
            "artistLocation": artistLocation,
            "serviceId": serviceId,
            "serviceName": serviceName,
            "serviceCategory": serviceCategory,
            "servicePrice": servicePrice,
            "serviceDuration": serviceDuration,
            "serviceDescription": serviceDescription,
            "date": Timestamp(date: date),
            "timeSlot": timeSlot,
            "endTime": endTime,
            "status": status.rawValue,
            "inspoImages": inspoImages,
            "specialRequests": specialRequests,
            "textNotifications": textNotifications,
            "createdAt": Timestamp(date: createdAt)
        ]
        
        if let clientProfileImageURL = clientProfileImageURL {
            data["clientProfileImageURL"] = clientProfileImageURL
        }
        if let artistProfileImageURL = artistProfileImageURL {
            data["artistProfileImageURL"] = artistProfileImageURL
        }
        if let updatedAt = updatedAt {
            data["updatedAt"] = Timestamp(date: updatedAt)
        }
        if let confirmedAt = confirmedAt {
            data["confirmedAt"] = Timestamp(date: confirmedAt)
        }
        if let cancelledAt = cancelledAt {
            data["cancelledAt"] = Timestamp(date: cancelledAt)
        }
        if let cancelReason = cancelReason {
            data["cancelReason"] = cancelReason
        }
        
        return data
    }
    
    static func fromFirestore(document: DocumentSnapshot) -> Appointment? {
        guard let data = document.data() else { return nil }
        
        return Appointment(
            id: document.documentID,
            clientId: data["clientId"] as? String ?? "",
            clientName: data["clientName"] as? String ?? "",
            clientEmail: data["clientEmail"] as? String ?? "",
            clientPhone: data["clientPhone"] as? String ?? "",
            clientProfileImageURL: data["clientProfileImageURL"] as? String,
            artistId: data["artistId"] as? String ?? "",
            artistName: data["artistName"] as? String ?? "",
            artistProfileImageURL: data["artistProfileImageURL"] as? String,
            artistLocation: data["artistLocation"] as? String ?? "",
            serviceId: data["serviceId"] as? String ?? "",
            serviceName: data["serviceName"] as? String ?? "",
            serviceCategory: data["serviceCategory"] as? String ?? "",
            servicePrice: data["servicePrice"] as? Double ?? 0,
            serviceDuration: data["serviceDuration"] as? Int ?? 60,
            serviceDescription: data["serviceDescription"] as? String ?? "",
            date: (data["date"] as? Timestamp)?.dateValue() ?? Date(),
            timeSlot: data["timeSlot"] as? String ?? "",
            endTime: data["endTime"] as? String ?? "",
            status: AppointmentStatus(rawValue: data["status"] as? String ?? "pending") ?? .pending,
            inspoImages: data["inspoImages"] as? [String] ?? [],
            specialRequests: data["specialRequests"] as? String ?? "",
            textNotifications: data["textNotifications"] as? Bool ?? false,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue(),
            confirmedAt: (data["confirmedAt"] as? Timestamp)?.dateValue(),
            cancelledAt: (data["cancelledAt"] as? Timestamp)?.dateValue(),
            cancelReason: data["cancelReason"] as? String
        )
    }
}

// MARK: - Time Slot Model
struct TimeSlot: Identifiable, Equatable {
    let id = UUID()
    let time: String           // "10:00 AM"
    let hour: Int              // 10
    let minute: Int            // 0
    var isAvailable: Bool
    
    var period: String {
        hour < 12 ? "Morning" : "Afternoon"
    }
    
    static func generateSlots(from startHour: Int = 9, to endHour: Int = 18, interval: Int = 30) -> [TimeSlot] {
        var slots: [TimeSlot] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        var currentHour = startHour
        var currentMinute = 0
        
        while currentHour < endHour || (currentHour == endHour && currentMinute == 0) {
            var components = DateComponents()
            components.hour = currentHour
            components.minute = currentMinute
            
            if let date = Calendar.current.date(from: components) {
                let timeString = formatter.string(from: date)
                slots.append(TimeSlot(
                    time: timeString,
                    hour: currentHour,
                    minute: currentMinute,
                    isAvailable: true
                ))
            }
            
            currentMinute += interval
            if currentMinute >= 60 {
                currentMinute = 0
                currentHour += 1
            }
        }
        
        return slots
    }
}

// MARK: - Booking Flow State
class BookingState: ObservableObject {
    @Published var selectedService: ServiceItem?
    @Published var selectedDate: Date = Date()
    @Published var selectedTimeSlot: TimeSlot?
    @Published var inspoImages: [String] = []
    @Published var specialRequests: String = ""
    @Published var textNotifications: Bool = false
    @Published var clientPhone: String = ""
    
    // Computed end time
    var endTime: String {
        guard let service = selectedService, let slot = selectedTimeSlot else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        var components = DateComponents()
        components.hour = slot.hour
        components.minute = slot.minute
        
        guard let startDate = Calendar.current.date(from: components) else { return "" }
        guard let endDate = Calendar.current.date(byAdding: .minute, value: service.duration, to: startDate) else { return "" }
        
        return formatter.string(from: endDate)
    }
    
    func reset() {
        selectedService = nil
        selectedDate = Date()
        selectedTimeSlot = nil
        inspoImages = []
        specialRequests = ""
        textNotifications = false
        clientPhone = ""
    }
}
