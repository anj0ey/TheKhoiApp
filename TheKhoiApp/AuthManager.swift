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
    let id: String
    var fullName: String
    var email: String
    var username: String
    var bio: String
    var location: String? // 👈 ADDED THIS
    
    init(
        id: String,
        fullName: String,
        email: String,
        username: String,
        bio: String,
        location: String? = nil // 👈 ADDED THIS
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.username = username
        self.bio = bio
        self.location = location
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
    
    @Published var isBusinessMode: Bool = UserDefaults.standard.bool(forKey: "isBusinessMode") {
        didSet {
            UserDefaults.standard.set(isBusinessMode, forKey: "isBusinessMode")
        }
    }
    
    //Firebase userID
    private var db = Firestore.firestore()
    @Published var firebaseUID: String?
    
    // Where we store the profile in UserDefaults
    private let userKey = "currentUserProfile"
    
    func toggleUserMode() {
            isBusinessMode.toggle()
            print("🔄 User switched to \(isBusinessMode ? "Business" : "Customer") mode")
        }
    
    init() {
        // Check if Firebase already has an active session
        checkAuthState()
    }
    
    // MARK: - Check Auth State on Launch
    
    private func checkAuthState() {
        isCheckingAuth = true
        
        // 1. Check if there is a locally saved user
        guard let user = Auth.auth().currentUser else {
            self.isOnboardingComplete = false
            self.needsProfileSetup = false
            self.currentUser = nil
            self.isCheckingAuth = false
            return
        }
        
        // 2. CRITICAL FIX: Verify with Firebase Server that this user actually exists
        user.reload { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                // ❌ Case A: User was deleted in Firebase Console!
                print("DEBUG: User token is invalid (User deleted?). Logging out. Error: \(error.localizedDescription)")
                
                // Force local sign out to clean up the "Zombie" state
                try? Auth.auth().signOut()
                
                // Reset state to show Login Screen
                self.isOnboardingComplete = false
                self.needsProfileSetup = false
                self.currentUser = nil
                self.isCheckingAuth = false
                
            } else {
                // ✅ Case B: User is valid on server. Proceed to check Firestore.
                print("DEBUG: User is valid. Fetching profile...")
                self.firebaseUID = user.uid
                self.authenticatedEmail = user.email
                self.authenticatedName = user.displayName
                
                // Now we are safe to look for the profile
                self.fetchUser(uid: user.uid)
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
        print("🔍 Checking for existing profile for UID: \(uid)")
        
        let docRef = db.collection("users").document(uid)
        
        docRef.getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            // 1. Handle Errors (Network issues, etc.)
            if let error = error {
                print("❌ Error fetching profile: \(error.localizedDescription)")
                // Don't force profile setup on error; just stop loading or show alert
                self.isCheckingAuth = false
                return
            }
            
            // 2. Check if Document Exists
            if let document = document, document.exists {
                print("✅ Found existing user profile")
                
                // Decode the user data
                do {
                    // Make sure your UserProfile struct matches the fields in Firestore!
                    // If fields are missing/renamed, this try? might fail.
                    let profile = try document.data(as: UserProfile.self)
                    
                    DispatchQueue.main.async {
                        self.currentUser = profile
                        self.isOnboardingComplete = true
                        self.needsProfileSetup = false // CRITICAL: Mark as setup complete
                        self.isCheckingAuth = false
                    }
                } catch {
                    print("❌ Error decoding user profile: \(error)")
                    // If decoding fails, we technically have a profile but it's corrupt.
                    // You might want to let them fix it or contact support.
                    self.isCheckingAuth = false
                }
            } else {
                // 3. Document DOES NOT Exist -> Send to Setup
                print("⚠️ No profile found for this UID. Redirecting to Profile Setup.")
                DispatchQueue.main.async {
                    self.needsProfileSetup = true // CRITICAL: This triggers the screen switch
                    self.isOnboardingComplete = false
                    self.isCheckingAuth = false
                }
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
            id: uid,
            fullName: authenticatedName ?? "",
            email: authenticatedEmail ?? "",
            username: username,
            bio: bio
        )
        
        let data: [String: Any] = [
            "id": uid,
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
    
    // MARK: - Business Profile Creation
        
        // PASTE THE FUNCTION HERE 👇
        func upgradeToBusinessProfile(businessName: String, category: String, city: String, completion: @escaping (Bool) -> Void) {
            guard let uid = firebaseUID, let user = currentUser else {
                completion(false)
                return
            }
            
            // Ensure db is available (defined at top of class)
            let db = Firestore.firestore()
            
            // 1. Create the Artist Data Object
            let newArtistData: [String: Any] = [
                "id": uid,                          // ID matches User ID
                "ownerId": uid,                     // Link to Auth User
                "fullName": businessName,           // Business Name
                "username": user.username,
                "email": user.email,
                "city": city,
                "services": [category],             // e.g. ["Nails"]
                "claimed": true,                    // Owned by user
                "createdAt": Timestamp(date: Date()),
                "rating": 5.0,
                "reviewCount": 0,
                "bio": "",
                "profileImageURL": "",
                "coverImageURL": ""
            ]
            
            // 2. Save to "artists" collection
            db.collection("artists").document(uid).setData(newArtistData) { error in
                if let error = error {
                    print("Error creating business profile: \(error.localizedDescription)")
                    completion(false)
                } else {
                    // 3. Update Local State
                    DispatchQueue.main.async {
                        self.isBusinessMode = true
                    }
                    completion(true)
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
    
    func fetchUser(uid: String) {
        let db = Firestore.firestore()
        
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            // 1. Stop the loading animation once we get a response
            DispatchQueue.main.async {
                self.isCheckingAuth = false
            }
            
            // 2. Check if the profile exists in Firestore
            if let document = snapshot, document.exists {
                // ✅ Case A: User exists! Load their data and go to RootView.
                do {
                    self.currentUser = try document.data(as: UserProfile.self)
                    self.isOnboardingComplete = true  // <--- KEY FIX: This lets them pass the login screen
                    self.needsProfileSetup = false
                } catch {
                    print("DEBUG: Error decoding user profile: \(error)")
                    // If data is corrupt, force them to setup again or handle error
                    self.isOnboardingComplete = false
                    self.needsProfileSetup = true
                }
            } else {
                // ⚠️ Case B: User has a login but NO profile. Send to Profile Setup.
                print("DEBUG: No profile found for \(uid)")
                self.isOnboardingComplete = false
                self.needsProfileSetup = true
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
