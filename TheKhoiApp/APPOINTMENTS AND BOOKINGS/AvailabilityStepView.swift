//
//  AvailabilityStepView.swift
//  TheKhoiApp
//
//

import SwiftUI

// MARK: - Step 5: Availability
struct Step5AvailabilityView: View {
    @Binding var application: ProApplication
    let onNext: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Set your working hours")
                    .font(KHOITheme.body)
                    .foregroundColor(KHOIColors.mutedText)
                    .padding(.horizontal)
                
                Text("Clients can only book during these times")
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.mutedText)
                    .padding(.horizontal)
                
                // Days of the week
                VStack(spacing: 12) {
                    ForEach(0..<7, id: \.self) { index in
                        let dayInfo = application.availability.allDays[index]
                        DayAvailabilityRow(
                            dayName: dayInfo.name,
                            availability: binding(for: dayInfo.weekday)
                        )
                    }
                }
                .padding(.horizontal)
                
                // Quick actions
                VStack(spacing: 12) {
                    Button(action: setWeekdayDefaults) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("Set weekday defaults (9 AM - 5 PM)")
                        }
                        .font(KHOITheme.caption)
                        .foregroundColor(KHOIColors.accentBrown)
                    }
                    
                    Button(action: clearAll) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Clear all")
                        }
                        .font(KHOITheme.caption)
                        .foregroundColor(KHOIColors.mutedText)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                Spacer(minLength: 100)
            }
            .padding(.top, 16)
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingButtonPair(
                backAction: onBack,
                nextTitle: "Continue",
                isNextEnabled: application.isStep5Valid,
                nextAction: onNext
            )
        }
    }
    
    private func binding(for weekday: Int) -> Binding<DayAvailability> {
        Binding(
            get: { application.availability.availability(for: weekday) },
            set: { application.availability.setAvailability(for: weekday, $0) }
        )
    }
    
    private func setWeekdayDefaults() {
        withAnimation {
            application.availability.monday = DayAvailability(isOpen: true, startHour: 9, endHour: 17)
            application.availability.tuesday = DayAvailability(isOpen: true, startHour: 9, endHour: 17)
            application.availability.wednesday = DayAvailability(isOpen: true, startHour: 9, endHour: 17)
            application.availability.thursday = DayAvailability(isOpen: true, startHour: 9, endHour: 17)
            application.availability.friday = DayAvailability(isOpen: true, startHour: 9, endHour: 17)
            application.availability.saturday = DayAvailability(isOpen: false)
            application.availability.sunday = DayAvailability(isOpen: false)
        }
    }
    
    private func clearAll() {
        withAnimation {
            application.availability = BusinessAvailability(
                sunday: DayAvailability(isOpen: false),
                monday: DayAvailability(isOpen: false),
                tuesday: DayAvailability(isOpen: false),
                wednesday: DayAvailability(isOpen: false),
                thursday: DayAvailability(isOpen: false),
                friday: DayAvailability(isOpen: false),
                saturday: DayAvailability(isOpen: false)
            )
        }
    }
}

// MARK: - Day Availability Row
struct DayAvailabilityRow: View {
    let dayName: String
    @Binding var availability: DayAvailability
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(dayName)
                    .font(KHOITheme.bodyBold)
                    .foregroundColor(KHOIColors.darkText)
                    .frame(width: 100, alignment: .leading)
                
                Spacer()
                
                Toggle("", isOn: $availability.isOpen)
                    .labelsHidden()
                    .tint(KHOIColors.accentBrown)
            }
            
            if availability.isOpen {
                HStack(spacing: 12) {
                    // Start time
                    TimePickerButton(
                        label: "From",
                        hour: $availability.startHour,
                        minute: $availability.startMinute
                    )
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12))
                        .foregroundColor(KHOIColors.mutedText)
                    
                    // End time
                    TimePickerButton(
                        label: "To",
                        hour: $availability.endHour,
                        minute: $availability.endMinute
                    )
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(KHOIColors.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Time Picker Button
struct TimePickerButton: View {
    let label: String
    @Binding var hour: Int
    @Binding var minute: Int
    
    @State private var showPicker = false
    
    private var displayTime: String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }
    
    var body: some View {
        Button(action: { showPicker = true }) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(KHOIColors.mutedText)
                Text(displayTime)
                    .font(KHOITheme.body)
                    .foregroundColor(KHOIColors.darkText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(KHOIColors.chipBackground)
            .cornerRadius(8)
        }
        .sheet(isPresented: $showPicker) {
            TimePickerSheet(hour: $hour, minute: $minute)
                .presentationDetents([.height(300)])
        }
    }
}

// MARK: - Time Picker Sheet
struct TimePickerSheet: View {
    @Binding var hour: Int
    @Binding var minute: Int
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack(spacing: 0) {
                    // Hour picker
                    Picker("Hour", selection: $hour) {
                        ForEach(0..<24, id: \.self) { h in
                            Text(formatHour(h)).tag(h)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 100)
                    
                    Text(":")
                        .font(.title2)
                    
                    // Minute picker
                    Picker("Minute", selection: $minute) {
                        ForEach([0, 15, 30, 45], id: \.self) { m in
                            Text(String(format: "%02d", m)).tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                    
                    // AM/PM indicator
                    Text(hour >= 12 ? "PM" : "AM")
                        .font(KHOITheme.bodyBold)
                        .foregroundColor(KHOIColors.accentBrown)
                        .frame(width: 50)
                }
            }
            .padding()
            .navigationTitle("Select Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(KHOIColors.accentBrown)
                }
            }
        }
    }
    
    private func formatHour(_ h: Int) -> String {
        let displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return "\(displayHour)"
    }
}
