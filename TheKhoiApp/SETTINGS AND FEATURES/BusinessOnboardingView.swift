//
//  BusinessOnboardingView.swift
//  TheKhoiApp
//
//  Created by Anjo on 12/2/25.
//

import SwiftUI

struct BusinessOnboardingView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var businessName = ""
    @State private var city = ""
    @State private var selectedCategory = "Makeup"
    @State private var isLoading = false
    
    let categories = ["Makeup", "Nails", "Hair", "Lashes", "Brows", "Skin"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Business Details")) {
                    TextField("Business Name", text: $businessName)
                    TextField("City", text: $city)
                    
                    Picker("Primary Service", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }
                
                Section {
                    Button(action: createBusiness) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Launch Business Profile")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Become a Pro")
        }
    }
    
    func createBusiness() {
        isLoading = true
        authManager.upgradeToBusinessProfile(
            businessName: businessName,
            category: selectedCategory,
            city: city
        ) { success in
            isLoading = false
            if success {
                dismiss() // Close the sheet
            }
        }
    }
}
