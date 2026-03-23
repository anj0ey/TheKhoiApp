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
    
    var startTimeFormatted: String {
        formatTimeWithMinutes(hour: startHour, minute: startMinute)
    }
    
    var endTimeFormatted: String {
        formatTimeWithMinutes(hour: endHour, minute: endMinute)
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
    
    private func formatTimeWithMinutes(hour: Int, minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
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

// MARK: - Buffer Time Options
enum BufferTime: Int, CaseIterable, Codable {
    case none = 0
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case fortyFiveMinutes = 45
    case oneHour = 60
    
    var displayString: String {
        switch self {
        case .none: return "No buffer"
        case .fifteenMinutes: return "15 minutes"
        case .thirtyMinutes: return "30 minutes"
        case .fortyFiveMinutes: return "45 minutes"
        case .oneHour: return "1 hour"
        }
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
    
    // Buffer time between appointments (in minutes)
    var bufferMinutes: Int = 15
    
    // Vacation dates (dates when the business is closed)
    var vacationDates: [Date] = []
    
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
    
    // Get availability for a Date (also checks vacation dates)
    func availability(for date: Date) -> DayAvailability {
        // Check if date is a vacation day
        if isVacationDay(date) {
            return DayAvailability(isOpen: false)
        }
        
        let weekday = Calendar.current.component(.weekday, from: date)
        return availability(for: weekday)
    }
    
    // Check if a date is a vacation day
    func isVacationDay(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return vacationDates.contains { vacationDate in
            calendar.isDate(vacationDate, inSameDayAs: date)
        }
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
    
    // Get open days for compact display
    var openDays: [Int] {
        var days: [Int] = []
        if monday.isOpen { days.append(2) }
        if tuesday.isOpen { days.append(3) }
        if wednesday.isOpen { days.append(4) }
        if thursday.isOpen { days.append(5) }
        if friday.isOpen { days.append(6) }
        if saturday.isOpen { days.append(7) }
        if sunday.isOpen { days.append(1) }
        return days
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
    
    mutating func toggleDay(_ weekday: Int) {
        switch weekday {
        case 1: sunday.isOpen.toggle()
        case 2: monday.isOpen.toggle()
        case 3: tuesday.isOpen.toggle()
        case 4: wednesday.isOpen.toggle()
        case 5: thursday.isOpen.toggle()
        case 6: friday.isOpen.toggle()
        case 7: saturday.isOpen.toggle()
        default: break
        }
    }
    
    // Set the same hours for all open days
    mutating func setUniformHours(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        if sunday.isOpen {
            sunday.startHour = startHour
            sunday.startMinute = startMinute
            sunday.endHour = endHour
            sunday.endMinute = endMinute
        }
        if monday.isOpen {
            monday.startHour = startHour
            monday.startMinute = startMinute
            monday.endHour = endHour
            monday.endMinute = endMinute
        }
        if tuesday.isOpen {
            tuesday.startHour = startHour
            tuesday.startMinute = startMinute
            tuesday.endHour = endHour
            tuesday.endMinute = endMinute
        }
        if wednesday.isOpen {
            wednesday.startHour = startHour
            wednesday.startMinute = startMinute
            wednesday.endHour = endHour
            wednesday.endMinute = endMinute
        }
        if thursday.isOpen {
            thursday.startHour = startHour
            thursday.startMinute = startMinute
            thursday.endHour = endHour
            thursday.endMinute = endMinute
        }
        if friday.isOpen {
            friday.startHour = startHour
            friday.startMinute = startMinute
            friday.endHour = endHour
            friday.endMinute = endMinute
        }
        if saturday.isOpen {
            saturday.startHour = startHour
            saturday.startMinute = startMinute
            saturday.endHour = endHour
            saturday.endMinute = endMinute
        }
    }
    
    // Add a vacation date
    mutating func addVacationDate(_ date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        if !vacationDates.contains(where: { calendar.isDate($0, inSameDayAs: startOfDay) }) {
            vacationDates.append(startOfDay)
        }
    }
    
    // Remove a vacation date
    mutating func removeVacationDate(_ date: Date) {
        let calendar = Calendar.current
        vacationDates.removeAll { calendar.isDate($0, inSameDayAs: date) }
    }
    
    func toFirestoreData() -> [String: Any] {
        return [
            "sunday": sunday.toFirestoreData(),
            "monday": monday.toFirestoreData(),
            "tuesday": tuesday.toFirestoreData(),
            "wednesday": wednesday.toFirestoreData(),
            "thursday": thursday.toFirestoreData(),
            "friday": friday.toFirestoreData(),
            "saturday": saturday.toFirestoreData(),
            "bufferMinutes": bufferMinutes,
            "vacationDates": vacationDates.map { Timestamp(date: $0) }
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
        
        availability.bufferMinutes = data["bufferMinutes"] as? Int ?? 15
        
        if let vacationTimestamps = data["vacationDates"] as? [Timestamp] {
            availability.vacationDates = vacationTimestamps.map { $0.dateValue() }
        }
        
        return availability
    }
}

// MARK: - Time Options for Picker
struct TimeOption: Identifiable, Equatable, Hashable {
    let id = UUID()
    let hour: Int
    let minute: Int
    
    var displayString: String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
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
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(hour)
        hasher.combine(minute)
    }
    
    static func == (lhs: TimeOption, rhs: TimeOption) -> Bool {
        lhs.hour == rhs.hour && lhs.minute == rhs.minute
    }
}
