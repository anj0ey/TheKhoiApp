//
//  ArtistProfileView.swift
//  TheKhoiApp
//
//  Created by Anjo on 12/2/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Artist Profile View
struct ArtistProfileView: View {
    let artist: Artist
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    // UI State
    @State private var selectedTab: String = "Posts"
    @State private var showBookingSheet = false
    @State private var isSaved = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            KHOIColors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // 1. Header (Cover + Avatar)
                    headerSection
                    
                    // 2. Info (Name, Bio, Stats)
                    infoSection
                    
                    // 3. Tabs (Posts / Services / Reviews)
                    tabSection
                    
                    // 4. Content Grid
                    if selectedTab == "Posts" {
                        postsGrid
                    } else if selectedTab == "Services" {
                        servicesList
                    } else {
                        Text("No reviews yet.")
                            .foregroundColor(KHOIColors.mutedText)
                            .padding(.top, 40)
                    }
                    
                    // Spacer for the floating button
                    Color.clear.frame(height: 100)
                }
            }
            
            // 5. FLOATING BOOK BUTTON
            VStack {
                Spacer()
                Button(action: {
                    showBookingSheet = true
                }) {
                    Text("Book Appointment")
                        .font(KHOITheme.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(KHOIColors.darkText)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, KHOITheme.spacing_md)
                .padding(.bottom, KHOITheme.spacing_lg)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        // 👇 THIS PRESENTS THE BOOKING SHEET
        .sheet(isPresented: $showBookingSheet) {
            BookingSheetView(artist: artist, isPresented: $showBookingSheet)
        }
    }
    
    // MARK: - Components
    
    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Cover Image
            Rectangle()
                .fill(KHOIColors.cardBackground)
                .frame(height: 180)
                .overlay(
                    AsyncImage(url: URL(string: artist.coverImageURL ?? "")) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.1)
                    }
                )
                .clipped()
            
            // Avatar
            Circle()
                .stroke(KHOIColors.background, lineWidth: 4)
                .background(Circle().fill(KHOIColors.cardBackground))
                .frame(width: 90, height: 90)
                .overlay(
                    AsyncImage(url: URL(string: artist.profileImageURL ?? "")) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .foregroundColor(KHOIColors.mutedText)
                    }
                    .clipShape(Circle())
                )
                .offset(x: 20, y: 45) // Push it half out
        }
        .padding(.bottom, 50) // Make room for the avatar
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(artist.fullName)
                        .font(KHOITheme.heading2)
                        .foregroundColor(KHOIColors.darkText)
                    
                    Text("@\(artist.username)")
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.mutedText)
                }
                Spacer()
                
                // Save / Share Buttons
                HStack(spacing: 12) {
                    Button(action: { isSaved.toggle() }) {
                        Image(systemName: isSaved ? "heart.fill" : "heart")
                            .foregroundColor(isSaved ? KHOIColors.accentBrown : KHOIColors.darkText)
                            .font(.system(size: 20))
                            .padding(10)
                            .background(KHOIColors.cardBackground)
                            .clipShape(Circle())
                    }
                }
            }
            
            if !artist.bio.isEmpty {
                Text(artist.bio)
                    .font(KHOITheme.body)
                    .foregroundColor(KHOIColors.darkText)
                    .lineLimit(3)
            }
            
            // Stats
            HStack(spacing: 24) {
                statItem(value: "\(artist.referralCount)", label: "Referrals")
                statItem(value: String(format: "%.1f", artist.rating ?? 5.0), label: "Rating")
                statItem(value: artist.city, label: "Location")
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, KHOITheme.spacing_md)
    }
    
    private func statItem(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(KHOITheme.headline)
                .foregroundColor(KHOIColors.darkText)
            Text(label)
                .font(KHOITheme.caption)
                .foregroundColor(KHOIColors.mutedText)
        }
    }
    
    private var tabSection: some View {
        HStack(spacing: 0) {
            tabButton(title: "Posts")
            tabButton(title: "Services")
            tabButton(title: "Reviews")
        }
        .padding(.top, KHOITheme.spacing_lg)
        .padding(.bottom, KHOITheme.spacing_md)
        .padding(.horizontal, KHOITheme.spacing_md)
    }
    
    private func tabButton(title: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(KHOITheme.headline)
                .foregroundColor(selectedTab == title ? KHOIColors.darkText : KHOIColors.mutedText)
            
            Rectangle()
                .fill(selectedTab == title ? KHOIColors.accentBrown : Color.clear)
                .frame(height: 2)
        }
        .frame(maxWidth: .infinity)
        .onTapGesture {
            withAnimation { selectedTab = title }
        }
    }
    
    private var postsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            // Placeholder posts for now
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 200)
            }
        }
        .padding(KHOITheme.spacing_md)
    }
    
    private var servicesList: some View {
        VStack(spacing: 16) {
            ForEach(artist.services, id: \.self) { service in
                HStack {
                    VStack(alignment: .leading) {
                        Text(service)
                            .font(KHOITheme.body)
                            .bold()
                        Text("1 hr • $80") // Placeholder data
                            .font(KHOITheme.caption)
                            .foregroundColor(KHOIColors.mutedText)
                    }
                    Spacer()
                    Button("Book") {
                        showBookingSheet = true
                    }
                    .font(KHOITheme.caption.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(KHOIColors.darkText)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
                .background(KHOIColors.cardBackground)
                .cornerRadius(12)
            }
        }
        .padding(KHOITheme.spacing_md)
    }
}
