//
//  BusinessAvailability.swift
//  TheKhoiApp
//
//

import Foundation
import FirebaseFirestore

// MARK: - Day Availability
struct DayAvailability: Codable, Equatable {
    var isOpen: Bool = false
    var startHour: Int = 9      // 24-hour format
    var startMinute: Int = 0
    var endHour: Int = 17       // 24-hour format
    var endMinute: Int = 0
    
    var startTime: String {
        formatTime(hour: startHour, minute: startMinute)
    }
    
    var endTime: String {
        formatTime(hour: endHour, minute: endMinute)
    }
    
    private func formatTime(hour: Int, minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        if minute == 0 {
            return "\(displayHour) \(period)"
        } else {
            return String(format: "%d:%02d %@", displayHour, minute, period)
        }
    }
    
    func toFirestoreData() -> [String: Any] {
        return [
            "isOpen": isOpen,
            "startHour": startHour,
            "startMinute": startMinute,
            "endHour": endHour,
            "endMinute": endMinute
        ]
    }
    
    static func fromFirestore(_ data: [String: Any]) -> DayAvailability {
        return DayAvailability(
            isOpen: data["isOpen"] as? Bool ?? false,
            startHour: data["startHour"] as? Int ?? 9,
            startMinute: data["startMinute"] as? Int ?? 0,
            endHour: data["endHour"] as? Int ?? 17,
            endMinute: data["endMinute"] as? Int ?? 0
        )
    }
}

// MARK: - Weekly Availability
struct BusinessAvailability: Codable {
    var sunday: DayAvailability = DayAvailability(isOpen: false)
    var monday: DayAvailability = DayAvailability(isOpen: true, startHour: 9, endHour: 17)
    var tuesday: DayAvailability = DayAvailability(isOpen: true, startHour: 9, endHour: 17)
    var wednesday: DayAvailability = DayAvailability(isOpen: true, startHour: 9, endHour: 17)
    var thursday: DayAvailability = DayAvailability(isOpen: true, startHour: 9, endHour: 17)
    var friday: DayAvailability = DayAvailability(isOpen: true, startHour: 9, endHour: 17)
    var saturday: DayAvailability = DayAvailability(isOpen: false)
    
    // Get availability for a specific weekday (1 = Sunday, 7 = Saturday)
    func availability(for weekday: Int) -> DayAvailability {
        switch weekday {
        case 1: return sunday
        case 2: return monday
        case 3: return tuesday
        case 4: return wednesday
        case 5: return thursday
        case 6: return friday
        case 7: return saturday
        default: return DayAvailability(isOpen: false)
        }
    }
    
    // Get availability for a Date
    func availability(for date: Date) -> DayAvailability {
        let weekday = Calendar.current.component(.weekday, from: date)
        return availability(for: weekday)
    }
    
    // Check if a specific time slot is within availability
    func isTimeSlotAvailable(date: Date, hour: Int, minute: Int) -> Bool {
        let dayAvail = availability(for: date)
        
        guard dayAvail.isOpen else { return false }
        
        let slotMinutes = hour * 60 + minute
        let startMinutes = dayAvail.startHour * 60 + dayAvail.startMinute
        let endMinutes = dayAvail.endHour * 60 + dayAvail.endMinute
        
        return slotMinutes >= startMinutes && slotMinutes < endMinutes
    }
    
    // Get all days as an array for iteration
    var allDays: [(name: String, shortName: String, availability: DayAvailability, weekday: Int)] {
        [
            ("Sunday", "Sun", sunday, 1),
            ("Monday", "Mon", monday, 2),
            ("Tuesday", "Tue", tuesday, 3),
            ("Wednesday", "Wed", wednesday, 4),
            ("Thursday", "Thu", thursday, 5),
            ("Friday", "Fri", friday, 6),
            ("Saturday", "Sat", saturday, 7)
        ]
    }
    
    mutating func setAvailability(for weekday: Int, _ availability: DayAvailability) {
        switch weekday {
        case 1: sunday = availability
        case 2: monday = availability
        case 3: tuesday = availability
        case 4: wednesday = availability
        case 5: thursday = availability
        case 6: friday = availability
        case 7: saturday = availability
        default: break
        }
    }
    
    func toFirestoreData() -> [String: Any] {
        return [
            "sunday": sunday.toFirestoreData(),
            "monday": monday.toFirestoreData(),
            "tuesday": tuesday.toFirestoreData(),
            "wednesday": wednesday.toFirestoreData(),
            "thursday": thursday.toFirestoreData(),
            "friday": friday.toFirestoreData(),
            "saturday": saturday.toFirestoreData()
        ]
    }
    
    static func fromFirestore(_ data: [String: Any]) -> BusinessAvailability {
        var availability = BusinessAvailability()
        
        if let sundayData = data["sunday"] as? [String: Any] {
            availability.sunday = DayAvailability.fromFirestore(sundayData)
        }
        if let mondayData = data["monday"] as? [String: Any] {
            availability.monday = DayAvailability.fromFirestore(mondayData)
        }
        if let tuesdayData = data["tuesday"] as? [String: Any] {
            availability.tuesday = DayAvailability.fromFirestore(tuesdayData)
        }
        if let wednesdayData = data["wednesday"] as? [String: Any] {
            availability.wednesday = DayAvailability.fromFirestore(wednesdayData)
        }
        if let thursdayData = data["thursday"] as? [String: Any] {
            availability.thursday = DayAvailability.fromFirestore(thursdayData)
        }
        if let fridayData = data["friday"] as? [String: Any] {
            availability.friday = DayAvailability.fromFirestore(fridayData)
        }
        if let saturdayData = data["saturday"] as? [String: Any] {
            availability.saturday = DayAvailability.fromFirestore(saturdayData)
        }
        
        return availability
    }
}

// MARK: - Time Options for Picker
struct TimeOption: Identifiable, Equatable {
    let id = UUID()
    let hour: Int
    let minute: Int
    
    var displayString: String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        if minute == 0 {
            return "\(displayHour):00 \(period)"
        } else {
            return String(format: "%d:%02d %@", displayHour, minute, period)
        }
    }
    
    var totalMinutes: Int {
        hour * 60 + minute
    }
    
    static func allOptions(interval: Int = 30) -> [TimeOption] {
        var options: [TimeOption] = []
        for hour in 0..<24 {
            for minute in stride(from: 0, to: 60, by: interval) {
                options.append(TimeOption(hour: hour, minute: minute))
            }
        }
        return options
    }
    
    static func option(hour: Int, minute: Int) -> TimeOption {
        TimeOption(hour: hour, minute: minute)
    }
}
