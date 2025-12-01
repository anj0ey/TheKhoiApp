//
//  AuthManager.swift
//  TheKhoiApp
//
//  Created by iya student on 11/18/25.
//
import Foundation
import SwiftUI
import Combine
import AuthenticationServices
import GoogleSignIn
import UIKit

// MARK: - User Profile Model

struct UserProfile: Codable, Identifiable {
    let id: UUID
    var fullName: String
    var email: String
    var username: String
    var bio: String
    
    init(
        id: UUID = UUID(),
        fullName: String,
        email: String,
        username: String,
        bio: String
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.username = username
        self.bio = bio
    }
}

// MARK: - Auth Manager

final class AuthManager: ObservableObject {
    // Overall flow
    @Published var isOnboardingComplete: Bool
    @Published var needsProfileSetup: Bool = false
    
    // From Apple / Google providers
    @Published var authenticatedEmail: String?
    @Published var authenticatedName: String?
    
    // Finished user profile
    @Published var currentUser: UserProfile?
    
    // Where we store the profile in UserDefaults
    private let userKey = "currentUserProfile"
    
    init() {
        // Load stored state
        self.isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
        loadUser()
    }
    
    // MARK: - Persistence
    
    private func saveUser(_ user: UserProfile) {
        currentUser = user
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }
    
    private func loadUser() {
        guard
            let data = UserDefaults.standard.data(forKey: userKey),
            let user = try? JSONDecoder().decode(UserProfile.self, from: data)
        else { return }
        
        currentUser = user
    }
    
    private func completeOnboarding() {
        isOnboardingComplete = true
        needsProfileSetup = false
        UserDefaults.standard.set(true, forKey: "isOnboardingComplete")
    }
    
    // Call this from ProfileSetupView when user fills username + bio + password
    func finishProfileSetup(username: String, bio: String, password: String) {
        // ⚠️ demo only: do NOT store passwords in UserDefaults in real apps
        UserDefaults.standard.set(password, forKey: "demoPassword")
        
        let user = UserProfile(
            fullName: authenticatedName ?? "",
            email: authenticatedEmail ?? "",
            username: username,
            bio: bio
        )
        saveUser(user)
        completeOnboarding()
    }
    
    // MARK: - Sign in with Apple
    
    func handleAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }
    
    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                // Apple gives email & name only the first time
                let email = appleIDCredential.email
                
                let formatter = PersonNameComponentsFormatter()
                let fullName = appleIDCredential.fullName.flatMap { formatter.string(from: $0) }
                
                authenticatedEmail = email ?? authenticatedEmail
                authenticatedName = fullName ?? authenticatedName
                
                // If no profile exists yet, go to profile setup
                if currentUser == nil {
                    needsProfileSetup = true
                } else {
                    completeOnboarding()
                }
            }
        case .failure(let error):
            print("Sign in with Apple failed:", error.localizedDescription)
        }
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle() {
        guard let rootVC = UIApplication.shared.rootViewController else {
            print("No root view controller found")
            return
        }
        
        // Use your actual iOS client ID
        let config = GIDConfiguration(
            clientID: "103531796518-hrlg9c4nhhvkhms44aojra4fb937jqpo.apps.googleusercontent.com"
        )
        GIDSignIn.sharedInstance.configuration = config
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { [weak self] result, error in
            if let error = error {
                print("Google sign in failed:", error.localizedDescription)
                return
            }
            
            guard let self = self, let user = result?.user else { return }
            
            self.authenticatedEmail = user.profile?.email ?? self.authenticatedEmail
            self.authenticatedName = user.profile?.name ?? self.authenticatedName
            
            if self.currentUser == nil {
                self.needsProfileSetup = true
            } else {
                self.completeOnboarding()
            }
        }
    }
}


// MARK: - Helper to get root view controller

extension UIApplication {
    var rootViewController: UIViewController? {
        guard
            let scene = connectedScenes.first as? UIWindowScene,
            let window = scene.windows.first,
            let root = window.rootViewController
        else {
            return nil
        }
        return root
    }
}


//com.googleusercontent.apps.103531796518-hrlg9c4nhhvkhms44aojra4fb937jqpo
