//
//  AppointmentsView.swift
//  TheKhoiApp
//
//  Created by Anjo on 12/2/25.
//

import SwiftUI

struct AppointmentsView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 16) {
                    // Custom title
<<<<<<< Updated upstream
                    Text(authManager.isBusinessMode ? "SCHEDULE" : "BOOKINGS")
=======
                    Text(authManager.isBusinessMode ? "SCHEDULE" : "APPOINTMENTS")
>>>>>>> Stashed changes
                        .font(KHOITheme.headline)
                        .foregroundColor(KHOIColors.mutedText)
                        .tracking(2)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Your actual content
                    if authManager.isBusinessMode {
                        BusinessScheduleView()
                    } else {
                        CustomerBookingsView()
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)   // 🔥 hide the system bar
        }
    }
}


// MARK: - Customer View (My Bookings)
struct CustomerBookingsView: View {
    @State private var selectedTab = "Upcoming"
    
    var body: some View {
        VStack(spacing: 0) {
            // Tabs
            HStack {
                tabButton(title: "Upcoming")
                tabButton(title: "Past")
            }
            .padding()
            
            ScrollView {
                VStack(spacing: 16) {
                    if selectedTab == "Upcoming" {
                        BookingCard(service: "Soft Glam", artist: "Jen Wilson", date: "Nov 14", time: "1:00 PM", status: "Confirmed")
                        BookingCard(service: "Brow Lamination", artist: "Brows by Sarah", date: "Nov 20", time: "10:00 AM", status: "Pending")
                    } else {
                        BookingCard(service: "Full Set Lashes", artist: "Lash Lounge", date: "Oct 01", time: "3:00 PM", status: "Completed")
                    }
                }
                .padding()
            }
        }
    }
    
    func tabButton(title: String) -> some View {
        Button(action: { selectedTab = title }) {
            Text(title.uppercased())
                .font(.caption).bold()
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(selectedTab == title ? Color.white : Color.clear)
                .foregroundColor(selectedTab == title ? KHOIColors.darkText : KHOIColors.mutedText)
                .cornerRadius(12)
                .shadow(color: selectedTab == title ? Color.black.opacity(0.05) : .clear, radius: 5)
        }
    }
}

// MARK: - Business View (Availability)
struct BusinessScheduleView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Manage your availability for client bookings.")
                    .font(KHOITheme.body)
                    .foregroundColor(KHOIColors.mutedText)
                    .padding(.horizontal)
                
                // Weekly Schedule
                VStack(spacing: 1) {
                    ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                        HStack {
                            Text(day).bold().frame(width: 40)
                            Spacer()
                            Text("9:00 AM - 5:00 PM")
                                .font(.caption)
                                .padding(8)
                                .background(KHOIColors.background)
                                .cornerRadius(6)
                            
                            Toggle("", isOn: .constant(true))
                                .labelsHidden()
                                .tint(KHOIColors.accentBrown)
                        }
                        .padding()
                        .background(Color.white)
                    }
                }
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5)
                .padding(.horizontal)
                
                Button(action: {}) {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("Edit Calendar Settings")
                    }
                    .foregroundColor(KHOIColors.darkText)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(KHOIColors.darkText, lineWidth: 1))
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

// Helper Card
struct BookingCard: View {
    let service: String
    let artist: String
    let date: String
    let time: String
    let status: String
    
    var statusColor: Color {
        switch status {
        case "Confirmed": return .green
        case "Pending": return .orange
        case "Completed": return .gray
        default: return .black
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(service).font(KHOITheme.headline)
                    Text("with \(artist)").font(.caption).foregroundColor(KHOIColors.mutedText)
                }
                Spacer()
                Text(status)
                    .font(.caption).bold()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.1))
                    .foregroundColor(statusColor)
                    .cornerRadius(8)
            }
            
            Divider()
            
            HStack {
                Label(date, systemImage: "calendar")
                Spacer()
                Label(time, systemImage: "clock")
            }
            .font(.caption)
            .foregroundColor(KHOIColors.darkText)
            
            if status == "Confirmed" {
                HStack(spacing: 12) {
                    Button("Reschedule") {}.font(.caption).bold().foregroundColor(KHOIColors.darkText)
                    Spacer()
                    Button("Message") {}.font(.caption).bold().foregroundColor(KHOIColors.accentBrown)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 8)
    }
}
