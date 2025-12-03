//
//  ProfileView.swift
//  TheKhoiApp
//
//  Created by Anjo on 12/2/25.
//

import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    
    // We pass this in ContentView, but it's optional for the UI
    var viewModel: HomeViewModel?
    @State private var showBusinessSetup = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // User Info Header
                        HStack(spacing: 16) {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(authManager.currentUser?.fullName ?? "User Name")
                                    .font(.title2).bold()
                                Text(authManager.currentUser?.username ?? "@username")
                                    .font(.subheadline)
                                    .foregroundColor(KHOIColors.mutedText)
                            }
                            Spacer()
                        }
                        .padding()
                        
                        // MARK: - MODE TOGGLE CARD
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Switch to Professional")
                                        .font(.headline)
                                    Text("Access availability and business tools")
                                        .font(.caption)
                                        .foregroundColor(KHOIColors.mutedText)
                                }
                                Spacer()
                                
                                // Direct binding to AuthManager
                                Toggle("", isOn: $authManager.isBusinessMode)
                                    .labelsHidden()
                                    .tint(KHOIColors.darkText)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                        .padding(.horizontal)
                        .shadow(color: Color.black.opacity(0.03), radius: 5)
                        
                        if !authManager.isBusinessMode {
                            Button(action: { showBusinessSetup = true }) {
                                HStack {
                                    Image(systemName: "briefcase.fill")
                                        .foregroundColor(KHOIColors.accentBrown)
                                        .frame(width: 24)
                                    
                                    Text("Switch to Business Account")
                                        .font(.body)
                                        .foregroundColor(KHOIColors.darkText)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(KHOIColors.mutedText)
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Menu Items
                        VStack(spacing: 1) {
                            menuItem(icon: "gear", title: "Account Settings")
                            Divider().padding(.leading)
                            menuItem(icon: "creditcard", title: "Payment Methods")
                            Divider().padding(.leading)
                            menuItem(icon: "heart", title: "Favorites")
                            Divider().padding(.leading)
                            menuItem(icon: "questionmark.circle", title: "Help & Support")
                        }
                        .background(Color.white)
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        // Sign Out
                        Button(action: { authManager.logOut() }) {
                            Text("Log Out")
                                .foregroundColor(.red)
                                .font(.subheadline).bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(16)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom)
                }
            }
            .sheet(isPresented: $showBusinessSetup) {
                        BusinessOnboardingView()
                            .environmentObject(authManager)
                    }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    func menuItem(icon: String, title: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(KHOIColors.darkText)
                .frame(width: 24)
            Text(title)
                .font(.body)
                .foregroundColor(KHOIColors.darkText)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(KHOIColors.mutedText)
        }
        .padding()
    }
}
