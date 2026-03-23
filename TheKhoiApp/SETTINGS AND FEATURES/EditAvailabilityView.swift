//
//  EditAvailabilityView.swift
//  TheKhoiApp
//
//  Created by Khoi Nguyen on 2/24/26.
//


import SwiftUI
import FirebaseFirestore

struct EditAvailabilityView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    @State private var availability: BusinessAvailability = BusinessAvailability()
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    
    // Time picker state
    @State private var selectedStartHour = 10
    @State private var selectedStartMinute = 0
    @State private var selectedEndHour = 17
    @State private var selectedEndMinute = 0
    
    // Vacation calendar state
    @State private var selectedMonth = Date()
    @State private var selectedVacationDates: Set<Date> = []
    
    private let calendar = Calendar.current
    private let timeOptions = TimeOption.allOptions(interval: 30)
    
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .tint(KHOIColors.accentBrown)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Days and Time Section
                            daysAndTimeSection
                            
                            // Vacation Time Section
                            vacationTimeSection
                            
                            Spacer(minLength: 100)
                        }
                        .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(KHOIColors.darkText)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("AVAILABILITY")
                        .font(KHOITheme.headline)
                        .tracking(2)
                        .foregroundColor(KHOIColors.mutedText)
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Save button
                Button(action: saveChanges) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Save")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(KHOIColors.darkText)
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.bottom, 20)
                .background(KHOIColors.background)
            }
            .onAppear {
                loadAvailability()
            }
            .alert("Saved!", isPresented: $showSaveSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your availability has been updated.")
            }
        }
    }
    
    // MARK: - Days and Time Section
    
    private var daysAndTimeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DAYS AND TIME")
                .font(.system(size: 13, weight: .bold))
                .tracking(1)
                .foregroundColor(KHOIColors.darkText)
            
            // Day selection
            VStack(alignment: .leading, spacing: 8) {
                Text("What days are you open for work?")
                    .font(.system(size: 13))
                    .foregroundColor(KHOIColors.mutedText)
                
                HStack(spacing: 8) {
                    ForEach([(2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")], id: \.0) { weekday, name in
                        DayToggleButton(
                            name: name,
                            isSelected: isDayOpen(weekday),
                            action: { toggleDay(weekday) }
                        )
                    }
                }
            }
            
            // Time selection
            VStack(alignment: .leading, spacing: 8) {
                Text("What time are you open for work?")
                    .font(.system(size: 13))
                    .foregroundColor(KHOIColors.mutedText)
                
                HStack(spacing: 16) {
                    // Start time
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start time")
                            .font(.system(size: 11))
                            .foregroundColor(KHOIColors.mutedText)
                        
                        TimeDropdown(
                            hour: $selectedStartHour,
                            minute: $selectedStartMinute,
                            onChange: updateAllDaysTimes
                        )
                    }
                    
                    // End time
                    VStack(alignment: .leading, spacing: 4) {
                        Text("End time")
                            .font(.system(size: 11))
                            .foregroundColor(KHOIColors.mutedText)
                        
                        TimeDropdown(
                            hour: $selectedEndHour,
                            minute: $selectedEndMinute,
                            onChange: updateAllDaysTimes
                        )
                    }
                }
            }
            
            // Buffer time
            VStack(alignment: .leading, spacing: 8) {
                Text("How much time do you need between appointments?")
                    .font(.system(size: 13))
                    .foregroundColor(KHOIColors.mutedText)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time gap")
                        .font(.system(size: 11))
                        .foregroundColor(KHOIColors.mutedText)
                    
                    BufferTimeDropdown(selectedBuffer: $availability.bufferMinutes)
                }
            }
        }
    }
    
    // MARK: - Vacation Time Section
    
    private var vacationTimeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("VACATION TIME")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1)
                    .foregroundColor(KHOIColors.darkText)
                
                Spacer()
                
                Text("(Optional)")
                    .font(.system(size: 12))
                    .foregroundColor(KHOIColors.mutedText)
            }
            
            Text("Select days you'll be on vacation.")
                .font(.system(size: 13))
                .foregroundColor(KHOIColors.mutedText)
            
            // Month navigation
            HStack {
                Text(monthYearString(from: selectedMonth))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(KHOIColors.darkText)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(KHOIColors.accentBrown)
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: previousMonth) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14))
                            .foregroundColor(KHOIColors.darkText)
                    }
                    
                    Button(action: nextMonth) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(KHOIColors.darkText)
                    }
                }
            }
            
            // Calendar grid
            VacationCalendarGrid(
                month: selectedMonth,
                selectedDates: $selectedVacationDates,
                onDateTapped: { date in
                    toggleVacationDate(date)
                }
            )
        }
    }
    
    // MARK: - Helper Functions
    
    private func isDayOpen(_ weekday: Int) -> Bool {
        availability.availability(for: weekday).isOpen
    }
    
    private func toggleDay(_ weekday: Int) {
        availability.toggleDay(weekday)
    }
    
    private func updateAllDaysTimes() {
        availability.setUniformHours(
            startHour: selectedStartHour,
            startMinute: selectedStartMinute,
            endHour: selectedEndHour,
            endMinute: selectedEndMinute
        )
    }
    
    private func toggleVacationDate(_ date: Date) {
        let startOfDay = calendar.startOfDay(for: date)
        if selectedVacationDates.contains(where: { calendar.isDate($0, inSameDayAs: startOfDay) }) {
            selectedVacationDates.remove(startOfDay)
            availability.removeVacationDate(date)
        } else {
            selectedVacationDates.insert(startOfDay)
            availability.addVacationDate(date)
        }
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func previousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
            selectedMonth = newMonth
        }
    }
    
    private func nextMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
            selectedMonth = newMonth
        }
    }
    
    // MARK: - Data Loading
    
    private func loadAvailability() {
        guard let userId = authManager.firebaseUID else {
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        
        // Try artists collection first
        db.collection("artists").document(userId).getDocument { snapshot, error in
            if let data = snapshot?.data(),
               let availData = data["availability"] as? [String: Any] {
                self.availability = BusinessAvailability.fromFirestore(availData)
                self.syncTimeFromAvailability()
                self.syncVacationDates()
            } else {
                // Try pro_applications
                db.collection("pro_applications").document(userId).getDocument { snapshot, _ in
                    if let data = snapshot?.data(),
                       let availData = data["availability"] as? [String: Any] {
                        self.availability = BusinessAvailability.fromFirestore(availData)
                        self.syncTimeFromAvailability()
                        self.syncVacationDates()
                    }
                    self.isLoading = false
                }
                return
            }
            self.isLoading = false
        }
    }
    
    private func syncTimeFromAvailability() {
        // Get time from first open day
        for day in availability.allDays {
            if day.availability.isOpen {
                selectedStartHour = day.availability.startHour
                selectedStartMinute = day.availability.startMinute
                selectedEndHour = day.availability.endHour
                selectedEndMinute = day.availability.endMinute
                break
            }
        }
    }
    
    private func syncVacationDates() {
        selectedVacationDates = Set(availability.vacationDates.map { calendar.startOfDay(for: $0) })
    }
    
    // MARK: - Save
    
    private func saveChanges() {
        guard let userId = authManager.firebaseUID else { return }
        
        isSaving = true
        
        let db = Firestore.firestore()
        let updateData: [String: Any] = [
            "availability": availability.toFirestoreData()
        ]
        
        // Update artists collection
        db.collection("artists").document(userId).updateData(updateData) { error in
            if error != nil {
                // Try pro_applications
                db.collection("pro_applications").document(userId).updateData(updateData) { _ in
                    self.isSaving = false
                    self.showSaveSuccess = true
                }
            } else {
                self.isSaving = false
                self.showSaveSuccess = true
            }
        }
    }
}

// MARK: - Day Toggle Button

struct DayToggleButton: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : KHOIColors.darkText)
                .frame(width: 40, height: 36)
                .background(isSelected ? KHOIColors.darkText : Color.clear)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.clear : KHOIColors.divider, lineWidth: 1)
                )
        }
    }
}

// MARK: - Time Dropdown

struct TimeDropdown: View {
    @Binding var hour: Int
    @Binding var minute: Int
    var onChange: (() -> Void)? = nil
    
    @State private var showPicker = false
    
    private var displayTime: String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }
    
    var body: some View {
        Button(action: { showPicker = true }) {
            HStack {
                Text(displayTime)
                    .font(.system(size: 14))
                    .foregroundColor(KHOIColors.darkText)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(KHOIColors.mutedText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(KHOIColors.cardBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(KHOIColors.divider, lineWidth: 1)
            )
        }
        .frame(width: 140)
        .sheet(isPresented: $showPicker) {
            TimePickerSheet(hour: $hour, minute: $minute)
                .presentationDetents([.height(300)])
                .onDisappear {
                    onChange?()
                }
        }
    }
}

// MARK: - Buffer Time Dropdown

struct BufferTimeDropdown: View {
    @Binding var selectedBuffer: Int
    @State private var showPicker = false
    
    private var displayText: String {
        switch selectedBuffer {
        case 0: return "No buffer"
        case 15: return "15 minutes"
        case 30: return "30 minutes"
        case 45: return "45 minutes"
        case 60: return "1 hour"
        default: return "\(selectedBuffer) minutes"
        }
    }
    
    var body: some View {
        Menu {
            ForEach([0, 15, 30, 45, 60], id: \.self) { minutes in
                Button(action: { selectedBuffer = minutes }) {
                    HStack {
                        Text(bufferText(for: minutes))
                        if selectedBuffer == minutes {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text(displayText)
                    .font(.system(size: 14))
                    .foregroundColor(KHOIColors.darkText)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(KHOIColors.mutedText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(KHOIColors.cardBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(KHOIColors.divider, lineWidth: 1)
            )
        }
        .frame(width: 140)
    }
    
    private func bufferText(for minutes: Int) -> String {
        switch minutes {
        case 0: return "No buffer"
        case 60: return "1 hour"
        default: return "\(minutes) minutes"
        }
    }
}

// MARK: - Vacation Calendar Grid

struct VacationCalendarGrid: View {
    let month: Date
    @Binding var selectedDates: Set<Date>
    var onDateTapped: (Date) -> Void
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    var body: some View {
        VStack(spacing: 8) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12))
                        .foregroundColor(KHOIColors.mutedText)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Days grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date = date {
                        let isSelected = selectedDates.contains(where: { calendar.isDate($0, inSameDayAs: date) })
                        let isCurrentMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)
                        
                        Button(action: { onDateTapped(date) }) {
                            Text("\(calendar.component(.day, from: date))")
                                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? .white : (isCurrentMonth ? KHOIColors.darkText : KHOIColors.mutedText.opacity(0.5)))
                                .frame(width: 36, height: 36)
                                .background(isSelected ? KHOIColors.darkText : Color.clear)
                                .cornerRadius(18)
                        }
                    } else {
                        Text("")
                            .frame(width: 36, height: 36)
                    }
                }
            }
        }
        .padding()
        .background(KHOIColors.cardBackground)
        .cornerRadius(12)
    }
    
    private func daysInMonth() -> [Date?] {
        var days: [Date?] = []
        
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return days
        }
        
        // Adjust for Monday start
        var startDate = firstWeek.start
        let weekdayOfFirst = calendar.component(.weekday, from: monthInterval.start)
        let mondayAdjustedWeekday = weekdayOfFirst == 1 ? 7 : weekdayOfFirst - 1
        startDate = calendar.date(byAdding: .day, value: -(mondayAdjustedWeekday - 1), to: monthInterval.start)!
        
        // Generate 6 weeks of dates
        for i in 0..<42 {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                days.append(date)
            }
        }
        
        return days
    }
}

// MARK: - Preview

#Preview {
    EditAvailabilityView()
        .environmentObject(AuthManager())
}
