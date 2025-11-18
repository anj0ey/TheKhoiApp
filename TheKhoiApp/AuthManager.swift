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

final class AuthManager: ObservableObject {
    @Published var isOnboardingComplete: Bool
    
    init() {
        // Load stored state so onboarding doesn't repeat
        self.isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
    }
    
    private func completeOnboarding() {
        isOnboardingComplete = true
        UserDefaults.standard.set(true, forKey: "isOnboardingComplete")
    }
    
    // MARK: - Sign in with Apple
    
    func handleAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }
    
    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userID = appleIDCredential.user
                UserDefaults.standard.set(userID, forKey: "appleUserID")
                completeOnboarding()
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
        
        // TODO: replace with your real iOS client ID from Google Cloud
        let config = GIDConfiguration(clientID: "103531796518-hrlg9c4nhhvkhms44aojra4fb937jqpo.apps.googleusercontent.com")
        GIDSignIn.sharedInstance.configuration = config
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { [weak self] result, error in
            if let error = error {
                print("Google sign in failed:", error.localizedDescription)
                return
            }
            
            guard let user = result?.user else { return }
            UserDefaults.standard.set(user.userID, forKey: "googleUserID")
            self?.completeOnboarding()
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
