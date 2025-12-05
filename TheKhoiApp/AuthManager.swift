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
import FirebaseStorage
import CryptoKit

// MARK: - User Profile Model

struct UserProfile: Codable, Identifiable {
    let id: String
    var fullName: String
    var email: String
    var username: String
    var bio: String
    var location: String?
    var profileImageURL: String?
    var coverImageURL: String?
    
    init(
        id: String,
        fullName: String,
        email: String,
        username: String,
        bio: String,
        location: String? = nil,
        profileImageURL: String? = nil,
        coverImageURL: String? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.username = username
        self.bio = bio
        self.location = location
        self.profileImageURL = profileImageURL
        self.coverImageURL = coverImageURL
    }
}

// MARK: - Auth Manager

final class AuthManager: ObservableObject {
    // Overall flow
    @Published var isOnboardingComplete: Bool = false
    @Published var needsProfileSetup: Bool = false
    @Published var isCheckingAuth: Bool = true
    
    // From Apple / Google providers
    @Published var authenticatedEmail: String?
    @Published var authenticatedName: String?
    
    // Finished user profile
    @Published var currentUser: UserProfile?
    
    // MARK: - Business Profile State
    /// True only if user has completed business onboarding (has artist document in Firestore)
    @Published var hasBusinessProfile: Bool = false
    
    /// Controls which mode the UI shows. Can only be true if hasBusinessProfile is true.
    @Published var isBusinessMode: Bool = false {
        didSet {
            // Only allow business mode if user has a business profile
            if isBusinessMode && !hasBusinessProfile {
                isBusinessMode = false
                return
            }
            UserDefaults.standard.set(isBusinessMode, forKey: "isBusinessMode")
        }
    }
    
    //Firebase userID
    private var db = Firestore.firestore()
    @Published var firebaseUID: String?
    
    // Where we store the profile in UserDefaults
    private let userKey = "currentUserProfile"
    
    func toggleUserMode() {
        // Only toggle if user has business profile
        guard hasBusinessProfile else {
            print("⚠️ Cannot switch to Business mode: No business profile")
            return
        }
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
            self.hasBusinessProfile = false
            self.isBusinessMode = false
            self.isCheckingAuth = false
            return
        }
        
        // 2. CRITICAL FIX: Verify with Firebase Server that this user actually exists
        user.reload { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                // User was deleted in Firebase Console
                print("DEBUG: User token is invalid (User deleted?). Logging out. Error: \(error.localizedDescription)")
                
                // Force local sign out to clean up the "Zombie" state
                try? Auth.auth().signOut()
                
                // Reset state to show Login Screen
                self.isOnboardingComplete = false
                self.needsProfileSetup = false
                self.currentUser = nil
                self.hasBusinessProfile = false
                self.isBusinessMode = false
                self.isCheckingAuth = false
                
            } else {
                // User is valid on server. Proceed to check Firestore.
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
    
    // MARK: - Check for Existing Profile
    private func checkExistingProfile(uid: String) {
        print("🔍 Checking for existing profile for UID: \(uid)")
        
        let docRef = db.collection("users").document(uid)
        
        docRef.getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error fetching profile: \(error.localizedDescription)")
                self.isCheckingAuth = false
                return
            }
            
            if let document = document, document.exists {
                print("✅ Found existing user profile")
                
                // Manual parsing to handle optional fields gracefully
                let data = document.data() ?? [:]
                let profile = UserProfile(
                    id: data["id"] as? String ?? uid,
                    fullName: data["fullName"] as? String ?? "",
                    email: data["email"] as? String ?? "",
                    username: data["username"] as? String ?? "",
                    bio: data["bio"] as? String ?? "",
                    location: data["location"] as? String,
                    profileImageURL: data["profileImageURL"] as? String,
                    coverImageURL: data["coverImageURL"] as? String
                )
                
                DispatchQueue.main.async {
                    self.currentUser = profile
                    self.isOnboardingComplete = true
                    self.needsProfileSetup = false
                    
                    // Check for business profile after user profile is loaded
                    self.checkBusinessProfile(uid: uid)
                }
            } else {
                print("⚠️ No profile found for this UID. Redirecting to Profile Setup.")
                DispatchQueue.main.async {
                    self.needsProfileSetup = true
                    self.isOnboardingComplete = false
                    self.hasBusinessProfile = false
                    self.isBusinessMode = false
                    self.isCheckingAuth = false
                }
            }
        }
    }
    
    // MARK: - Check Business Profile
    /// Checks if user has an artist document in Firestore (completed business onboarding)
    private func checkBusinessProfile(uid: String) {
        print("🔍 Checking for business profile for UID: \(uid)")
        
        db.collection("artists").document(uid).getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let document = document, document.exists {
                    print("✅ User has a business profile")
                    self.hasBusinessProfile = true
                    
                    // Restore saved business mode preference only if they have a profile
                    let savedMode = UserDefaults.standard.bool(forKey: "isBusinessMode")
                    self.isBusinessMode = savedMode
                } else {
                    print("ℹ️ User does not have a business profile")
                    self.hasBusinessProfile = false
                    self.isBusinessMode = false // Force client mode
                }
                
                self.isCheckingAuth = false
            }
        }
    }
    
    // MARK: - Fetch User (called on auth state check)
    func fetchUser(uid: String) {
        checkExistingProfile(uid: uid)
    }
    
    func finishProfileSetup(username: String, bio: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        print("📝 Starting profile setup for:", username)
        
        guard let uid = firebaseUID else {
            print("❌ No Firebase UID available")
            completion(false, "Authentication error. Please try signing in again.")
            return
        }
        
        UserDefaults.standard.set(password, forKey: "demoPassword")
        
        let user = UserProfile(
            id: uid,
            fullName: authenticatedName ?? "",
            email: authenticatedEmail ?? "",
            username: username,
            bio: bio,
            location: nil,
            profileImageURL: nil,
            coverImageURL: nil
        )
        
        db.collection("users").document(uid).setData([
            "id": user.id,
            "fullName": user.fullName,
            "email": user.email,
            "username": user.username,
            "bio": user.bio,
            "profileImageURL": "",
            "coverImageURL": "",
            // Search fields (lowercase for case-insensitive search)
            "usernameLower": user.username.lowercased(),
            "fullNameLower": user.fullName.lowercased()
        ]) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Firestore write error:", error.localizedDescription)
                completion(false, "Failed to save profile. Please try again.")
                return
            }
            
            print("✅ Profile saved to Firestore successfully")
            
            DispatchQueue.main.async {
                self.currentUser = user
                self.saveUser(user)
                self.completeOnboarding()
                completion(true, nil)
            }
        }
    }
    
    // MARK: - Update Profile
    func updateProfile(
        fullName: String,
        username: String,
        bio: String,
        location: String,
        completion: @escaping (Bool) -> Void
    ) {
        guard let uid = firebaseUID else {
            completion(false)
            return
        }
        
        db.collection("users").document(uid).updateData([
            "fullName": fullName,
            "username": username,
            "bio": bio,
            "location": location,
            // Search fields (lowercase for case-insensitive search)
            "usernameLower": username.lowercased(),
            "fullNameLower": fullName.lowercased()
        ]) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error updating profile: \(error.localizedDescription)")
                completion(false)
            } else {
                // Update local user
                DispatchQueue.main.async {
                    self.currentUser?.fullName = fullName
                    self.currentUser?.username = username
                    self.currentUser?.bio = bio
                    self.currentUser?.location = location
                    if let user = self.currentUser {
                        self.saveUser(user)
                    }
                }
                completion(true)
            }
        }
    }
    
    // MARK: - Upload Profile Image
    func uploadProfileImage(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        guard let uid = firebaseUID,
              let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(false)
            return
        }
        
        let storageRef = Storage.storage().reference()
        let profileImageRef = storageRef.child("profile_images/\(uid).jpg")
        
        profileImageRef.putData(imageData, metadata: nil) { [weak self] _, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error uploading profile image: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            profileImageRef.downloadURL { url, error in
                if let error = error {
                    print("❌ Error getting download URL: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let downloadURL = url else {
                    completion(false)
                    return
                }
                
                // Update Firestore
                self.db.collection("users").document(uid).updateData([
                    "profileImageURL": downloadURL.absoluteString
                ]) { error in
                    if let error = error {
                        print("❌ Error updating profile image URL: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        DispatchQueue.main.async {
                            self.currentUser?.profileImageURL = downloadURL.absoluteString
                            if let user = self.currentUser {
                                self.saveUser(user)
                            }
                        }
                        completion(true)
                    }
                }
            }
        }
    }
    
    // MARK: - Upload Cover Image
    func uploadCoverImage(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        guard let uid = firebaseUID,
              let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(false)
            return
        }
        
        let storageRef = Storage.storage().reference()
        let coverImageRef = storageRef.child("cover_images/\(uid).jpg")
        
        coverImageRef.putData(imageData, metadata: nil) { [weak self] _, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error uploading cover image: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            coverImageRef.downloadURL { url, error in
                if let error = error {
                    print("❌ Error getting download URL: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let downloadURL = url else {
                    completion(false)
                    return
                }
                
                // Update Firestore
                self.db.collection("users").document(uid).updateData([
                    "coverImageURL": downloadURL.absoluteString
                ]) { error in
                    if let error = error {
                        print("❌ Error updating cover image URL: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        DispatchQueue.main.async {
                            self.currentUser?.coverImageURL = downloadURL.absoluteString
                            if let user = self.currentUser {
                                self.saveUser(user)
                            }
                        }
                        completion(true)
                    }
                }
            }
        }
    }
    
    // MARK: - Upgrade to Business Profile
    func upgradeToBusinessProfile(businessName: String, category: String, city: String, completion: @escaping (Bool) -> Void) {
        guard let uid = firebaseUID, let user = currentUser else {
            completion(false)
            return
        }
        
        let db = Firestore.firestore()
        
        let newArtistData: [String: Any] = [
            "id": uid,
            "ownerId": uid,
            "fullName": businessName,
            "username": user.username,
            "email": user.email,
            "city": city,
            "services": [category],
            "claimed": true,
            "createdAt": Timestamp(date: Date()),
            "rating": 5.0,
            "reviewCount": 0,
            "bio": "",
            "profileImageURL": user.profileImageURL ?? "",
            "coverImageURL": user.coverImageURL ?? ""
        ]
        
        db.collection("artists").document(uid).setData(newArtistData) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error creating business profile: \(error.localizedDescription)")
                completion(false)
            } else {
                DispatchQueue.main.async {
                    // CRITICAL: Set hasBusinessProfile BEFORE isBusinessMode
                    self.hasBusinessProfile = true
                    self.isBusinessMode = true
                }
                completion(true)
            }
        }
    }
    
    // MARK: - Log Out
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
        
        // 4. Reset business state
        hasBusinessProfile = false
        isBusinessMode = false
        
        // 5. Reset state
        isOnboardingComplete = false
        needsProfileSetup = false
        
        // 6. Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: userKey)
        UserDefaults.standard.removeObject(forKey: "isOnboardingComplete")
        UserDefaults.standard.removeObject(forKey: "isBusinessMode")
        
        print("🚪 User fully signed out")
    }
    
    // MARK: - Apple Sign In
    
    /// Called when Apple Sign In button requests authorization
    func handleAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }
    
    /// Called when Apple Sign In completes
    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            handleAppleSignIn(authorization: authorization, nonce: currentNonce)
        case .failure(let error):
            print("❌ Apple Sign In failed: \(error.localizedDescription)")
        }
    }
    
    /// Store the nonce for Apple Sign In
    private var currentNonce: String?
    
    func handleAppleSignIn(authorization: ASAuthorization, nonce: String?) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = nonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            print("❌ Unable to get Apple ID Token")
            return
        }
        
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        
        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Firebase Apple auth error:", error.localizedDescription)
                return
            }
            
            guard let user = authResult?.user else { return }
            
            print("✅ Apple Sign In successful for:", user.email ?? "No email")
            
            self.firebaseUID = user.uid
            self.authenticatedEmail = user.email
            
            if let fullName = appleIDCredential.fullName {
                let name = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                self.authenticatedName = name.isEmpty ? nil : name
            }
            
            self.checkExistingProfile(uid: user.uid)
        }
    }
    
    // MARK: - Google Sign In
    
    /// Alias for handleGoogleSignIn (used by OnboardingView)
    func signInWithGoogle() {
        handleGoogleSignIn()
    }
    
    func handleGoogleSignIn() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("❌ No Firebase client ID found")
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ No root view controller found")
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Google Sign In error:", error.localizedDescription)
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                print("❌ No user or ID token")
                return
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            
            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Firebase Google auth error:", error.localizedDescription)
                    return
                }
                
                guard let firebaseUser = authResult?.user else { return }
                
                print("✅ Google Sign In successful for:", firebaseUser.email ?? "No email")
                
                self.firebaseUID = firebaseUser.uid
                self.authenticatedEmail = firebaseUser.email
                self.authenticatedName = firebaseUser.displayName
                
                self.checkExistingProfile(uid: firebaseUser.uid)
            }
        }
    }
    
    // MARK: - Nonce Generation for Apple Sign In
    func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
}
