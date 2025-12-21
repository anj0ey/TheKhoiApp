//
//  BookingSheetView.swift
//  TheKhoiApp
//
//  Created by Anjo on 12/2/25.
//  FILE USED FOR DEMO
//

import SwiftUI

struct BookingSheetView: View {
    let artist: Artist
    @Binding var isPresented: Bool
    
    @State private var step = 1
    @State private var selectedService: String?
    @State private var selectedDate: Date = Date()
    @State private var selectedTime: String?
    
    // Mock Data for the prototype
    let timeSlotsMorning = ["10:00 AM", "10:45 AM", "11:15 AM"]
    let timeSlotsAfternoon = ["12:00 PM", "1:15 PM", "3:00 PM", "4:15 PM"]
    
    var body: some View {
        ZStack {
            KHOIColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    if step > 1 {
                        Button(action: { withAnimation { step -= 1 } }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(KHOIColors.darkText)
                        }
                    } else {
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(KHOIColors.darkText)
                        }
                    }
                    
                    Spacer()
                    Text(artist.displayHandle)
                        .font(KHOITheme.headline)
                        .foregroundColor(KHOIColors.darkText)
                    Spacer()
                    
                    // Invisible spacer for alignment
                    Image(systemName: "chevron.left").opacity(0)
                }
                .padding()
                .background(KHOIColors.background)
                
                // Content Steps
                Group {
                    if step == 1 { serviceSelectionStep }
                    else if step == 2 { detailsStep }
                    else if step == 3 { dateTimeStep }
                    else { summaryStep }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            }
        }
    }
    
    // MARK: - STEP 1: Services
    var serviceSelectionStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("SERVICES")
                    .font(KHOITheme.caption)
                    .tracking(2)
                    .foregroundColor(KHOIColors.mutedText)
                    .padding(.horizontal)
                
                ForEach(artist.services, id: \.self) { service in
                    Button(action: {
                        selectedService = service
                        withAnimation { step = 2 }
                    }) {
                        HStack(spacing: 16) {
                            // Placeholder Image for Service
                            Rectangle()
                                .fill(KHOIColors.softBrown.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(service)
                                    .font(KHOITheme.headline)
                                    .foregroundColor(KHOIColors.darkText)
                                Text("$90 • 90 min")
                                    .font(KHOITheme.body)
                                    .foregroundColor(KHOIColors.darkText)
                                Text("Click to select")
                                    .font(KHOITheme.caption2)
                                    .foregroundColor(KHOIColors.mutedText)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top)
        }
    }
    
    // MARK: - STEP 2: Details
    var detailsStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Gallery Grid Placeholder
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.2)).frame(height: 200)
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.2))
                }.frame(height: 200)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(selectedService ?? "")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(KHOIColors.darkText)
                
                Text("$90 / 90 min")
                    .font(.subheadline)
                    .foregroundColor(KHOIColors.mutedText)
            }
            .padding(.horizontal)
            
            Text("Includes luxury skin prep, mini facial, and touch up kit. Recommended for bridal makeup or special events.")
                .font(KHOITheme.body)
                .foregroundColor(KHOIColors.darkText)
                .lineSpacing(4)
                .padding(.horizontal)
            
            Divider().padding(.horizontal)
            
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "mappin.circle")
                    .foregroundColor(KHOIColors.darkText)
                VStack(alignment: .leading) {
                    Text("ARRIVAL").font(.caption).bold().tracking(1)
                    Text("Please arrive with clean skin.").font(.caption).foregroundColor(KHOIColors.mutedText)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            bottomButton(title: "Confirm Service", action: { withAnimation { step = 3 } })
        }
    }
    
    // MARK: - STEP 3: Date & Time
    var dateTimeStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Text("DATE & TIME")
                            .font(KHOITheme.caption).bold().tracking(2)
                            .foregroundColor(KHOIColors.mutedText)
                        Spacer()
                        Button("Show Calendar") { }
                            .font(.caption).bold()
                            .foregroundColor(Color.red.opacity(0.8))
                    }
                    .padding(.horizontal)
                    
                    // Horizontal Date Strip
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<10) { index in
                                let date = Calendar.current.date(byAdding: .day, value: index, to: Date())!
                                let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                                
                                VStack {
                                    Text(date.formatted(.dateTime.weekday(.abbreviated)))
                                        .font(.caption2).bold()
                                    Text(date.formatted(.dateTime.day()))
                                        .font(.title3).bold()
                                }
                                .frame(width: 55, height: 75)
                                .background(isSelected ? KHOIColors.darkText : Color.clear)
                                .foregroundColor(isSelected ? .white : KHOIColors.mutedText)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(KHOIColors.softBrown.opacity(0.3), lineWidth: isSelected ? 0 : 1)
                                )
                                .onTapGesture { selectedDate = date }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Time Slots
                    VStack(alignment: .leading, spacing: 16) {
                        timeSection(title: "MORNING", icon: "sun.max", times: timeSlotsMorning)
                        timeSection(title: "AFTERNOON", icon: "sun.min", times: timeSlotsAfternoon)
                    }
                    .padding(.horizontal)
                }
            }
            
            bottomButton(title: "Confirm Info", isDisabled: selectedTime == nil, action: { withAnimation { step = 4 } })
        }
    }
    
    // MARK: - STEP 4: Summary
    var summaryStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Avatar Overlap
                    ZStack {
                        Circle() // Client
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 80, height: 80)
                            .offset(x: -20)
                            .overlay(Circle().stroke(KHOIColors.background, lineWidth: 4).offset(x: -20))
                        
                        AsyncImage(url: URL(string: artist.profileImageURL ?? "")) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.gray
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(KHOIColors.background, lineWidth: 4))
                        .offset(x: 20)
                    }
                    .padding(.top, 20)
                    
                    Text("You are booking with \(artist.fullName)")
                        .font(KHOITheme.caption)
                        .foregroundColor(KHOIColors.mutedText)
                    
                    // Ticket Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) {
                            Text(selectedService ?? "Service")
                                .font(.title2).bold()
                                .foregroundColor(KHOIColors.darkText)
                            Spacer()
                            Text("$90")
                                .font(.body)
                                .foregroundColor(KHOIColors.mutedText)
                        }
                        
                        Divider()
                        
                        HStack(spacing: 12) {
                            Image(systemName: "calendar")
                            Text(selectedDate.formatted(date: .long, time: .omitted))
                                .font(.callout).bold()
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "clock")
                            Text(selectedTime ?? "--:--")
                                .font(.callout).bold()
                        }
                    }
                    .padding(24)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 10)
                    .padding(.horizontal)
                    
                    // Notes
                    VStack(alignment: .leading) {
                        Text("Any special requests? (Optional)")
                            .font(.subheadline).bold()
                            .foregroundColor(KHOIColors.darkText)
                        
                        Text("Share your ideas...")
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 100, alignment: .top)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
                    }
                    .padding(.horizontal)
                }
            }
            
            bottomButton(title: "Confirm Booking", action: { isPresented = false })
        }
    }
    
    // MARK: - Helpers
    
    func timeSection(title: String, icon: String, times: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                Text(title).font(.caption).bold().tracking(1)
            }
            .foregroundColor(KHOIColors.mutedText)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                ForEach(times, id: \.self) { time in
                    Button(action: { selectedTime = time }) {
                        Text(time)
                            .font(.caption).bold()
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(selectedTime == time ? KHOIColors.darkText : Color.clear)
                            .foregroundColor(selectedTime == time ? .white : KHOIColors.darkText)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(KHOIColors.softBrown.opacity(0.3), lineWidth: selectedTime == time ? 0 : 1)
                            )
                    }
                }
            }
        }
    }
    
    func bottomButton(title: String, isDisabled: Bool = false, action: @escaping () -> Void) -> some View {
        VStack {
            Spacer()
            Button(action: action) {
                Text(title)
                    .font(KHOITheme.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isDisabled ? Color.gray.opacity(0.4) : KHOIColors.darkText)
                    .cornerRadius(16)
            }
            .disabled(isDisabled)
            .padding()
            .background(KHOIColors.background.opacity(0.95))
        }
        .frame(height: 100)
    }
}
