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
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore
import CryptoKit

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
    @Published var isOnboardingComplete: Bool = false
    @Published var needsProfileSetup: Bool = false
    @Published var isCheckingAuth: Bool = true // NEW: Loading state
    
    // From Apple / Google providers
    @Published var authenticatedEmail: String?
    @Published var authenticatedName: String?
    
    // Finished user profile
    @Published var currentUser: UserProfile?
    
    //Firebase userID
    private var db = Firestore.firestore()
    @Published var firebaseUID: String?
    
    // Where we store the profile in UserDefaults
    private let userKey = "currentUserProfile"
    
    init() {
        // Check if Firebase already has an active session
        checkAuthState()
    }
    
    // MARK: - Check Auth State on Launch
    
    private func checkAuthState() {
        // Check if user is already signed into Firebase
        if let firebaseUser = Auth.auth().currentUser {
            print("🔥 Found existing Firebase user:", firebaseUser.uid)
            self.firebaseUID = firebaseUser.uid
            self.authenticatedEmail = firebaseUser.email
            self.authenticatedName = firebaseUser.displayName
            
            // Check Firestore for profile
            checkExistingProfile(uid: firebaseUser.uid)
        } else {
            print("📱 No existing Firebase session")
            // No Firebase session, check local storage
            loadUser()
            isCheckingAuth = false
            
            // If we have a local profile but no Firebase session, that's weird
            if currentUser != nil {
                print("⚠️ Have local profile but no Firebase session - this shouldn't happen")
            }
        }
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
        DispatchQueue.main.async {
            self.isOnboardingComplete = true
            self.needsProfileSetup = false
            self.isCheckingAuth = false
            UserDefaults.standard.set(true, forKey: "isOnboardingComplete")
        }
    }
    
    // NEW: Check Firestore for existing profile
    private func checkExistingProfile(uid: String) {
        print("🔍 Checking Firestore for profile with UID:", uid)
        
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error fetching user profile:", error.localizedDescription)
                DispatchQueue.main.async {
                    self.needsProfileSetup = true
                    self.isCheckingAuth = false
                }
                return
            }
            
            guard let data = snapshot?.data(),
                  let fullName = data["fullName"] as? String,
                  let email = data["email"] as? String,
                  let username = data["username"] as? String,
                  let bio = data["bio"] as? String else {
                // No profile found in Firestore
                print("📝 No existing profile in Firestore → going to ProfileSetup")
                DispatchQueue.main.async {
                    self.needsProfileSetup = true
                    self.isCheckingAuth = false
                }
                return
            }
            
            // Profile exists! Load it locally
            print("✅ Existing profile found in Firestore")
            print("   Username:", username)
            let user = UserProfile(
                fullName: fullName,
                email: email,
                username: username,
                bio: bio
            )
            DispatchQueue.main.async {
                self.saveUser(user)
                self.completeOnboarding()
            }
        }
    }
    
    func finishProfileSetup(username: String, bio: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        print("📝 Starting profile setup for:", username)
        
        guard let uid = firebaseUID else {
            print("❌ No Firebase UID available")
            completion(false, "Authentication error. Please try signing in again.")
            return
        }
        
        // ⚠️ Demo only; password should be managed by FirebaseAuth normally.
        UserDefaults.standard.set(password, forKey: "demoPassword")
        
        let user = UserProfile(
            fullName: authenticatedName ?? "",
            email: authenticatedEmail ?? "",
            username: username,
            bio: bio
        )
        
        let data: [String: Any] = [
            "fullName": user.fullName,
            "fullNameLower": user.fullName.lowercased(),
            "email": user.email,
            "username": user.username,
            "usernameLower": user.username.lowercased(),
            "bio": user.bio,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        // First write to Firestore, then save locally
        db.collection("users").document(uid).setData(data, merge: true) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Firestore user write error:", error.localizedDescription)
                completion(false, "Failed to save profile. Please try again.")
                return
            }
            
            print("✅ User profile saved to Firestore")
            
            // Now save locally and complete onboarding
            DispatchQueue.main.async {
                self.saveUser(user)
                self.completeOnboarding()
                print("✅ Profile setup complete, moving to main app")
                completion(true, nil)
            }
        }
    }

    
    // MARK: - Sign in with Apple
    
    // Store the current nonce for Apple Sign-In
    private var currentNonce: String?
    
    func handleAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        
        // Generate and store nonce
        let nonce = randomNonceString()
        currentNonce = nonce
        request.nonce = sha256(nonce)
    }
    
    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                // Set loading state
                DispatchQueue.main.async {
                    self.isCheckingAuth = true
                }
                
                // Apple gives email & name only the first time
                let email = appleIDCredential.email
                
                let formatter = PersonNameComponentsFormatter()
                let fullName = appleIDCredential.fullName.flatMap { formatter.string(from: $0) }
                
                authenticatedEmail = email ?? authenticatedEmail
                authenticatedName = fullName ?? authenticatedName
                
                // Get the identity token
                guard let identityTokenData = appleIDCredential.identityToken,
                      let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                    print("❌ Unable to fetch identity token")
                    DispatchQueue.main.async {
                        self.isCheckingAuth = false
                    }
                    return
                }
                
                guard let nonce = currentNonce else {
                    print("❌ Invalid state: A login callback was received, but no login request was sent.")
                    DispatchQueue.main.async {
                        self.isCheckingAuth = false
                    }
                    return
                }
                
                // Create Firebase credential
                let credential = OAuthProvider.appleCredential(
                    withIDToken: identityToken,
                    rawNonce: nonce,
                    fullName: appleIDCredential.fullName
                )
                
                // Sign in to Firebase
                Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("❌ Firebase Apple auth error:", error.localizedDescription)
                        DispatchQueue.main.async {
                            self.isCheckingAuth = false
                        }
                        return
                    }
                    
                    print("✅ Firebase Apple auth success")
                    guard let uid = authResult?.user.uid else {
                        print("❌ No Firebase UID returned")
                        DispatchQueue.main.async {
                            self.isCheckingAuth = false
                        }
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self.firebaseUID = uid
                    }
                    print("firebaseUID:", uid)
                    
                    // Check Firestore for existing profile
                    self.checkExistingProfile(uid: uid)
                }
            }
        case .failure(let error):
            print("❌ Sign in with Apple failed:", error.localizedDescription)
        }
    }
    
    // MARK: - Nonce Helpers for Apple Sign-In
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    // MARK: - Google Sign In
    func signInWithGoogle() {
        guard let rootVC = UIApplication.shared.rootViewController else {
            print("❌ No root view controller found")
            return
        }
        
        // Set loading state
        DispatchQueue.main.async {
            self.isCheckingAuth = true
        }
        
        // Get client ID from Firebase config
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("❌ No Firebase client ID found")
            DispatchQueue.main.async {
                self.isCheckingAuth = false
            }
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Google sign in failed:", error.localizedDescription)
                DispatchQueue.main.async {
                    self.isCheckingAuth = false
                }
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                print("❌ Missing user or idToken from Google sign-in")
                DispatchQueue.main.async {
                    self.isCheckingAuth = false
                }
                return
            }
            
            let accessToken = user.accessToken.tokenString
            
            // Save display info for your profile flow
            DispatchQueue.main.async {
                self.authenticatedEmail = user.profile?.email ?? self.authenticatedEmail
                self.authenticatedName = user.profile?.name ?? self.authenticatedName
            }
            
            print("📧 Google email:", user.profile?.email ?? "nil")
            print("👤 Google name:", user.profile?.name ?? "nil")
            
            // Create Firebase credential
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )
            
            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Firebase Google auth error:", error.localizedDescription)
                    DispatchQueue.main.async {
                        self.isCheckingAuth = false
                    }
                    return
                }

                print("✅ Firebase Google auth success")
                guard let uid = authResult?.user.uid else {
                    print("❌ No Firebase UID returned")
                    DispatchQueue.main.async {
                        self.isCheckingAuth = false
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.firebaseUID = uid
                }
                print("firebaseUID:", uid)

                // Check Firestore for existing profile
                self.checkExistingProfile(uid: uid)
            }
        }
    }
    
    func logOut() {
        // 1. Sign out of Firebase
        do {
            try Auth.auth().signOut()
            print("✅ Firebase sign out successful")
        } catch {
            print("❌ Firebase sign out error:", error.localizedDescription)
        }
        
        // 2. Sign out of Google
        GIDSignIn.sharedInstance.signOut()
        print("✅ Google sign out successful")
        
        // 3. Clear all user data
        currentUser = nil
        firebaseUID = nil
        authenticatedEmail = nil
        authenticatedName = nil
        
        // 4. Reset onboarding flags
        isOnboardingComplete = false
        needsProfileSetup = false
        isCheckingAuth = false
        
        // 5. Remove stored profile locally
        UserDefaults.standard.removeObject(forKey: "currentUserProfile")
        UserDefaults.standard.removeObject(forKey: "isOnboardingComplete")
        
        print("✅ User logged out successfully")
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
