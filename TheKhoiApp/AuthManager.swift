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
    
    /// True if user has a pending pro application
    @Published var hasPendingProApplication: Bool = false
    
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
    
    // MARK: - Email Auth State
    @Published var isEmailLoading: Bool = false
    @Published var emailAuthError: String?
    
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
    
    // MARK: - Check if Email Exists in Database
    
    func checkEmailExists(email: String, completion: @escaping (Bool) -> Void) {
        isEmailLoading = true
        emailAuthError = nil
        
        // Check if email exists in users collection
        db.collection("users")
            .whereField("email", isEqualTo: email.lowercased().trimmingCharacters(in: .whitespaces))
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isEmailLoading = false
                    
                    if let error = error {
                        print("Error checking email: \(error.localizedDescription)")
                        self?.emailAuthError = "Error checking email. Please try again."
                        completion(false)
                        return
                    }
                    
                    let exists = !(snapshot?.documents.isEmpty ?? true)
                    print(exists ? "Email exists in database" : "Email not found, new user")
                    completion(exists)
                }
            }
    }
    
    // MARK: - Sign In with Email/Password
    
    func signInWithEmail(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        isEmailLoading = true
        emailAuthError = nil
        
        let trimmedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        
        Auth.auth().signIn(withEmail: trimmedEmail, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isEmailLoading = false
                
                if let error = error {
                    let nsError = error as NSError
                    var errorMessage = "Sign in failed. Please try again."
                    
                    // Handle specific Firebase Auth errors
                    if nsError.domain == "FIRAuthErrorDomain" {
                        switch nsError.code {
                        case 17009: // Wrong password
                            errorMessage = "Incorrect password. Please try again."
                        case 17011: // User not found
                            errorMessage = "No account found with this email."
                        case 17010: // Too many attempts
                            errorMessage = "Too many failed attempts. Please try again later."
                        default:
                            errorMessage = error.localizedDescription
                        }
                    }
                    
                    print("Email sign in error: \(error.localizedDescription)")
                    self.emailAuthError = errorMessage
                    completion(false, errorMessage)
                    return
                }
                
                guard let user = authResult?.user else {
                    completion(false, "Authentication failed.")
                    return
                }
                
                print("Email Sign In successful for: \(user.email ?? "No email")")
                
                self.firebaseUID = user.uid
                self.authenticatedEmail = user.email
                self.authenticatedName = user.displayName
                
                self.checkExistingProfile(uid: user.uid)
                completion(true, nil)
            }
        }
    }
    
    // MARK: - Create Account with Email/Password
    
    func createAccountWithEmail(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        isEmailLoading = true
        emailAuthError = nil
        
        let trimmedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        
        Auth.auth().createUser(withEmail: trimmedEmail, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isEmailLoading = false
                
                if let error = error {
                    let nsError = error as NSError
                    var errorMessage = "Account creation failed. Please try again."
                    
                    if nsError.domain == "FIRAuthErrorDomain" {
                        switch nsError.code {
                        case 17007: // Email already in use
                            errorMessage = "An account with this email already exists."
                        case 17008: // Invalid email
                            errorMessage = "Please enter a valid email address."
                        case 17026: // Weak password
                            errorMessage = "Password must be at least 6 characters."
                        default:
                            errorMessage = error.localizedDescription
                        }
                    }
                    
                    print("Create account error: \(error.localizedDescription)")
                    self.emailAuthError = errorMessage
                    completion(false, errorMessage)
                    return
                }
                
                guard let user = authResult?.user else {
                    completion(false, "Account creation failed.")
                    return
                }
                
                print("Account created successfully for: \(user.email ?? "No email")")
                
                self.firebaseUID = user.uid
                self.authenticatedEmail = user.email
                self.authenticatedName = nil // New user, no name yet
                
                // New user needs profile setup
                self.needsProfileSetup = true
                self.isOnboardingComplete = false
                
                completion(true, nil)
            }
        }
    }
    
    // MARK: - Continue with Email (Check + Route)
    
    func continueWithEmail(email: String, completion: @escaping (Bool, Bool) -> Void) {
        // Returns: (success, existingUser)
        // existingUser = true means they need to enter password
        // existingUser = false means they're new and need onboarding
        
        isEmailLoading = true
        emailAuthError = nil
        
        let trimmedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Check Firestore users collection for existing user
        // (fetchSignInMethods is deprecated and returns empty due to Email Enumeration Protection)
        db.collection("users")
            .whereField("email", isEqualTo: trimmedEmail)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isEmailLoading = false
                    
                    if let error = error {
                        print("Error checking email: \(error.localizedDescription)")
                        self?.emailAuthError = "Error checking email. Please try again."
                        completion(false, false)
                        return
                    }
                    
                    // If we found a user document, they exist
                    let userExists = !(snapshot?.documents.isEmpty ?? true)
                    self?.authenticatedEmail = trimmedEmail
                    
                    print(userExists ? "✅ Existing user found in Firestore" : "ℹ️ New user, not in Firestore")
                    completion(true, userExists)
                }
            }
    }
    
    // MARK: - Start New User Profile Setup (without Firebase account yet)
    
    func startNewUserProfileSetup(email: String) {
        let trimmedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        
        DispatchQueue.main.async {
            self.authenticatedEmail = trimmedEmail
            self.authenticatedName = nil
            self.needsProfileSetup = true
            self.isOnboardingComplete = false
        }
        
        print("Starting profile setup for new user: \(trimmedEmail)")
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
                print("Error fetching profile: \(error.localizedDescription)")
                self.isCheckingAuth = false
                return
            }
            
            if let document = document, document.exists {
                print("Found existing user profile")
                
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
                print("No profile found for this UID. Redirecting to Profile Setup.")
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
                    print("User has a business profile")
                    self.hasBusinessProfile = true
                    
                    // Restore saved business mode preference only if they have a profile
                    let savedMode = UserDefaults.standard.bool(forKey: "isBusinessMode")
                    self.isBusinessMode = savedMode
                } else {
                    print("User does not have a business profile")
                    self.hasBusinessProfile = false
                    self.isBusinessMode = false // Force client mode
                    
                    // Check for pending pro application
                    self.checkPendingProApplication()
                }
                
                self.isCheckingAuth = false
            }
        }
    }
    
    // MARK: - Fetch User (called on auth state check)
    func fetchUser(uid: String) {
        checkExistingProfile(uid: uid)
    }
    
    func finishProfileSetup(username: String, bio: String, fullName: String, password: String, profileImage: UIImage? = nil, coverImage: UIImage? = nil, completion: @escaping (Bool, String?) -> Void) {
        print("Starting profile setup for:", username)
        
        // If we don't have a Firebase UID yet, we need to create the account first
        if firebaseUID == nil {
            guard let email = authenticatedEmail else {
                completion(false, "No email found. Please try again.")
                return
            }
            
            // Create Firebase Auth account
            Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
                guard let self = self else { return }
                
                if let error = error {
                    let nsError = error as NSError
                    var errorMessage = "Account creation failed. Please try again."
                    
                    if nsError.domain == "FIRAuthErrorDomain" {
                        switch nsError.code {
                        case 17007:
                            errorMessage = "An account with this email already exists."
                        case 17008:
                            errorMessage = "Please enter a valid email address."
                        case 17026:
                            errorMessage = "Password must be at least 6 characters."
                        default:
                            errorMessage = error.localizedDescription
                        }
                    }
                    
                    print("Create account error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(false, errorMessage)
                    }
                    return
                }
                
                guard let user = authResult?.user else {
                    DispatchQueue.main.async {
                        completion(false, "Account creation failed.")
                    }
                    return
                }
                
                print("Firebase account created for: \(user.email ?? "No email")")
                
                // Now save the profile
                self.firebaseUID = user.uid
                self.saveProfileToFirestore(
                    uid: user.uid,
                    username: username,
                    bio: bio,
                    fullName: fullName,
                    profileImage: profileImage,
                    coverImage: coverImage,
                    completion: completion
                )
            }
        } else {
            // Already have Firebase UID (e.g., from Google Sign-In)
            saveProfileToFirestore(
                uid: firebaseUID!,
                username: username,
                bio: bio,
                fullName: fullName,
                profileImage: profileImage,
                coverImage: coverImage,
                completion: completion
            )
        }
    }
    
    private func saveProfileToFirestore(uid: String, username: String, bio: String, fullName: String, profileImage: UIImage? = nil, coverImage: UIImage? = nil, completion: @escaping (Bool, String?) -> Void) {
        let user = UserProfile(
            id: uid,
            fullName: fullName,
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
                print("Firestore write error:", error.localizedDescription)
                DispatchQueue.main.async {
                    completion(false, "Failed to save profile. Please try again.")
                }
                return
            }
            
            print("Profile saved to Firestore successfully")
            
            DispatchQueue.main.async {
                self.currentUser = user
                self.authenticatedName = fullName
                self.saveUser(user)
                self.completeOnboarding()
                
                // Upload images in background if provided
                if let profileImage = profileImage {
                    self.uploadProfileImage(profileImage) { _ in }
                }
                if let coverImage = coverImage {
                    self.uploadCoverImage(coverImage) { _ in }
                }
                
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
                print("Error updating profile: \(error.localizedDescription)")
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
                print("Error uploading profile image: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            profileImageRef.downloadURL { url, error in
                if let error = error {
                    print("Error getting download URL: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let downloadURL = url else {
                    completion(false)
                    return
                }
                
                // Update Firestore users collection
                self.db.collection("users").document(uid).updateData([
                    "profileImageURL": downloadURL.absoluteString
                ]) { error in
                    if let error = error {
                        print("Error updating profile image URL: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        DispatchQueue.main.async {
                            self.currentUser?.profileImageURL = downloadURL.absoluteString
                            if let user = self.currentUser {
                                self.saveUser(user)
                            }
                        }
                        
                        // ADDED: Also update artists collection if user has business profile
                        if self.hasBusinessProfile {
                            self.db.collection("artists").document(uid).updateData([
                                "profileImageURL": downloadURL.absoluteString
                            ]) { error in
                                if let error = error {
                                    print("Error updating artist profile image: \(error.localizedDescription)")
                                } else {
                                    print("Artist profile image updated")
                                }
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
                print("Error uploading cover image: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            coverImageRef.downloadURL { url, error in
                if let error = error {
                    print("Error getting download URL: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let downloadURL = url else {
                    completion(false)
                    return
                }
                
                // Update Firestore users collection
                self.db.collection("users").document(uid).updateData([
                    "coverImageURL": downloadURL.absoluteString
                ]) { error in
                    if let error = error {
                        print("Error updating cover image URL: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        DispatchQueue.main.async {
                            self.currentUser?.coverImageURL = downloadURL.absoluteString
                            if let user = self.currentUser {
                                self.saveUser(user)
                            }
                        }
                        
                        // ADDED: Also update artists collection if user has business profile
                        if self.hasBusinessProfile {
                            self.db.collection("artists").document(uid).updateData([
                                "coverImageURL": downloadURL.absoluteString
                            ]) { error in
                                if let error = error {
                                    print("Error updating artist cover image: \(error.localizedDescription)")
                                } else {
                                    print("Artist cover image updated")
                                }
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
    
    // MARK: - Pro Application Status
    
    /// Set pending pro application status
    func setPendingProStatus(_ isPending: Bool) {
        DispatchQueue.main.async {
            self.hasPendingProApplication = isPending
            UserDefaults.standard.set(isPending, forKey: "hasPendingProApplication")
        }
    }
    
    /// Check if user has a pending pro application
    func checkPendingProApplication() {
        guard let uid = firebaseUID else { return }
        
        db.collection("pro_applications").document(uid).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let document = snapshot, document.exists {
                let status = document.data()?["status"] as? String ?? ""
                DispatchQueue.main.async {
                    self.hasPendingProApplication = (status == "pending")
                    
                    // If approved, upgrade to business profile
                    if status == "approved" && !self.hasBusinessProfile {
                        self.upgradeFromApprovedApplication(document: document)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.hasPendingProApplication = false
                }
            }
        }
    }
    
    /// Upgrade user to business profile from approved application
    private func upgradeFromApprovedApplication(document: DocumentSnapshot) {
        guard let uid = firebaseUID,
              let user = currentUser,
              let data = document.data() else { return }
        
        let businessName = data["businessName"] as? String ?? user.fullName
        let location = data["location"] as? String ?? ""
        let bio = data["bio"] as? String ?? ""
        let servicesData = data["services"] as? [[String: Any]] ?? []
        let services = servicesData.map { $0["category"] as? String ?? "" }.filter { !$0.isEmpty }
        let policiesData = data["policies"] as? [String: Any]
        let portfolioData = data["portfolioImages"] as? [[String: Any]] ?? []
        
        var artistData: [String: Any] = [
            "id": uid,
            "ownerId": uid,
            "fullName": businessName,
            "username": user.username,
            "email": user.email,
            "city": location,
            "bio": bio,
            "services": services,
            "servicesDetailed": servicesData,
            "claimed": true,
            "verified": true,
            "createdAt": Timestamp(date: Date()),
            "rating": 5.0,
            "reviewCount": 0,
            "profileImageURL": user.profileImageURL ?? "",
            "coverImageURL": user.coverImageURL ?? "",
            "portfolioImages": portfolioData
        ]
        
        if let policies = policiesData {
            artistData["policies"] = policies
        }
        
        db.collection("artists").document(uid).setData(artistData) { [weak self] error in
            guard let self = self else { return }
            
            if error == nil {
                DispatchQueue.main.async {
                    self.hasBusinessProfile = true
                    self.hasPendingProApplication = false
                    self.isBusinessMode = true
                }
            }
        }
    }
    
    // MARK: - Log Out
    func logOut() {
        // 1. Sign out of Firebase
        do {
            try Auth.auth().signOut()
            print("Firebase sign out successful")
        } catch {
            print("Firebase sign out error:", error.localizedDescription)
        }
        
        // 2. Sign out of Google
        GIDSignIn.sharedInstance.signOut()
        print("Google sign out successful")
        
        // 3. Clear all user data
        currentUser = nil
        firebaseUID = nil
        authenticatedEmail = nil
        authenticatedName = nil
        
        // 4. Reset business state
        hasBusinessProfile = false
        isBusinessMode = false
        hasPendingProApplication = false
        
        // 5. Reset state
        isOnboardingComplete = false
        needsProfileSetup = false
        
        // 6. Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: userKey)
        UserDefaults.standard.removeObject(forKey: "isOnboardingComplete")
        UserDefaults.standard.removeObject(forKey: "isBusinessMode")
        UserDefaults.standard.removeObject(forKey: "hasPendingProApplication")
        
        print("🚪 User fully signed out")
    }
    
    // MARK: - Delete Account
    
    func deleteAccount(completion: @escaping (Bool, String?) -> Void) {
        guard let user = Auth.auth().currentUser,
              let uid = firebaseUID else {
            completion(false, "No user logged in")
            return
        }
        
        let batch = db.batch()
        
        // 1. Delete user document from Firestore
        let userRef = db.collection("users").document(uid)
        batch.deleteDocument(userRef)
        
        // 2. Delete artist profile if exists
        let artistRef = db.collection("artists").document(uid)
        batch.deleteDocument(artistRef)
        
        // 3. Delete pro application if exists
        let proAppRef = db.collection("pro_applications").document(uid)
        batch.deleteDocument(proAppRef)
        
        // Commit Firestore deletions first
        batch.commit { [weak self] error in
            if let error = error {
                print("❌ Error deleting Firestore data: \(error.localizedDescription)")
                completion(false, "Failed to delete account data. Please try again.")
                return
            }
            
            print("✅ Firestore data deleted")
            
            // 4. Delete profile images from Storage
            let storage = Storage.storage()
            let profileImageRef = storage.reference().child("profile_images/\(uid).jpg")
            let coverImageRef = storage.reference().child("cover_images/\(uid).jpg")
            
            // Delete images (don't fail if they don't exist)
            profileImageRef.delete { _ in }
            coverImageRef.delete { _ in }
            
            // 5. Delete Firebase Auth account
            user.delete { [weak self] error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error deleting Firebase Auth account: \(error.localizedDescription)")
                        
                        // Check if re-authentication is required
                        let nsError = error as NSError
                        if nsError.code == 17014 { // Requires recent login
                            completion(false, "For security, please log out and log back in, then try deleting your account again.")
                        } else {
                            completion(false, "Failed to delete account. Please try again.")
                        }
                        return
                    }
                    
                    print("✅ Firebase Auth account deleted")
                    
                    // 6. Clear local data (same as logOut)
                    self.currentUser = nil
                    self.firebaseUID = nil
                    self.authenticatedEmail = nil
                    self.authenticatedName = nil
                    self.hasBusinessProfile = false
                    self.isBusinessMode = false
                    self.hasPendingProApplication = false
                    self.isOnboardingComplete = false
                    self.needsProfileSetup = false
                    
                    UserDefaults.standard.removeObject(forKey: self.userKey)
                    UserDefaults.standard.removeObject(forKey: "isOnboardingComplete")
                    UserDefaults.standard.removeObject(forKey: "isBusinessMode")
                    UserDefaults.standard.removeObject(forKey: "hasPendingProApplication")
                    
                    // Sign out of Google if applicable
                    GIDSignIn.sharedInstance.signOut()
                    
                    print("🗑️ Account fully deleted")
                    completion(true, nil)
                }
            }
        }
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
            print("Apple Sign In failed: \(error.localizedDescription)")
        }
    }
    
    /// Store the nonce for Apple Sign In
    private var currentNonce: String?
    
    func handleAppleSignIn(authorization: ASAuthorization, nonce: String?) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = nonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            print("Unable to get Apple ID Token")
            return
        }
        
        // Extract name from Apple credential (only available on FIRST sign-in)
        var extractedName: String? = nil
        if let fullName = appleIDCredential.fullName {
            let nameParts = [fullName.givenName, fullName.familyName].compactMap { $0 }
            if !nameParts.isEmpty {
                extractedName = nameParts.joined(separator: " ")
                // Store in UserDefaults as backup since Apple only sends this once
                UserDefaults.standard.set(extractedName, forKey: "appleSignInName_\(appleIDCredential.user)")
                print("📝 Stored Apple name: \(extractedName ?? "nil")")
            }
        }
        
        // If no name from Apple, try to retrieve from UserDefaults (for returning users)
        if extractedName == nil || extractedName?.isEmpty == true {
            extractedName = UserDefaults.standard.string(forKey: "appleSignInName_\(appleIDCredential.user)")
            print("📝 Retrieved stored Apple name: \(extractedName ?? "nil")")
        }
        
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        
        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Firebase Apple auth error:", error.localizedDescription)
                return
            }
            
            guard let user = authResult?.user else { return }
            
            print("Apple Sign In successful for:", user.email ?? "No email")
            
            self.firebaseUID = user.uid
            self.authenticatedEmail = user.email ?? appleIDCredential.email
            
            // Priority for name:
            // 1. Name from Apple credential (first sign-in)
            // 2. Name stored in UserDefaults (returning users)
            // 3. Firebase displayName (if previously set)
            if let name = extractedName, !name.isEmpty {
                self.authenticatedName = name
            } else if let displayName = user.displayName, !displayName.isEmpty {
                self.authenticatedName = displayName
            } else {
                // No name available - user will enter it in ProfileSetupView
                self.authenticatedName = nil
            }
            
            print("Final authenticated name: \(self.authenticatedName ?? "nil")")
            
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
            print("No Firebase client ID found")
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("No root view controller found")
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Google Sign In error:", error.localizedDescription)
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                print("No user or ID token")
                return
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            
            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Firebase Google auth error:", error.localizedDescription)
                    return
                }
                
                guard let firebaseUser = authResult?.user else { return }
                
                print("Google Sign In successful for:", firebaseUser.email ?? "No email")
                
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
