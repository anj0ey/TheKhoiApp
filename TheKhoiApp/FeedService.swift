//
//  FeedService.swift
//  TheKhoiApp
//
//  Service to fetch posts and artists from Firestore
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit

class FeedService: ObservableObject {
    @Published var posts: [Post] = []
    @Published var artists: [Artist] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var postsListener: ListenerRegistration?
    
    // MARK: - Posts
    
    /// Fetch all posts for the feed
    func fetchPosts(category: String? = nil) {
        isLoading = true
        errorMessage = nil
        
        var query: Query = db.collection("posts")
            .order(by: "createdAt", descending: true)
        
        if let category = category, category != "All" {
            query = query.whereField("tag", isEqualTo: category)
        }
        
        query.limit(to: 50).getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.errorMessage = error.localizedDescription
                print("Error fetching posts: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else {
                self.posts = []
                return
            }
            
            self.posts = documents.compactMap { Post(document: $0) }
        }
    }
    
    /// Listen to posts in real-time
    func listenToPosts(category: String? = nil) {
        postsListener?.remove()
        isLoading = true
        
        var query: Query = db.collection("posts")
            .order(by: "createdAt", descending: true)
        
        if let category = category, category != "All" {
            query = query.whereField("tag", isEqualTo: category)
        }
        
        postsListener = query.limit(to: 50).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            self.posts = documents.compactMap { Post(document: $0) }
        }
    }
    
    /// Increment save count for a post
    func incrementSaveCount(postId: String) {
        db.collection("posts").document(postId).updateData([
            "saveCount": FieldValue.increment(Int64(1))
        ])
    }
    
    /// Decrement save count for a post
    func decrementSaveCount(postId: String) {
        db.collection("posts").document(postId).updateData([
            "saveCount": FieldValue.increment(Int64(-1))
        ])
    }
    
    // MARK: - Artists
    
    /// Fetch artist by ID
    func fetchArtist(artistId: String, completion: @escaping (Artist?) -> Void) {
        db.collection("artists").document(artistId).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching artist: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let snapshot = snapshot else {
                completion(nil)
                return
            }
            
            completion(Artist(document: snapshot))
        }
    }
    
    /// Fetch all featured artists
    func fetchFeaturedArtists() {
        db.collection("artists")
            .whereField("featured", isEqualTo: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching artists: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                self.artists = documents.compactMap { Artist(document: $0) }
            }
    }
    
    /// Search artists
    func searchArtists(query: String, completion: @escaping ([Artist]) -> Void) {
        let searchLower = query.lowercased()
        
        db.collection("artists")
            .whereField("usernameLower", isGreaterThanOrEqualTo: searchLower)
            .whereField("usernameLower", isLessThanOrEqualTo: searchLower + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error searching artists: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                let artists = documents.compactMap { Artist(document: $0) }
                completion(artists)
            }
    }
    
    // MARK: - Claim Profile
    
    /// Submit a claim request for an artist profile
    func submitClaimRequest(
        artistId: String,
        userId: String,
        userEmail: String,
        userName: String,
        verificationNote: String,
        instagramHandle: String?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Check if user already has a pending claim
        db.collection("claimRequests")
            .whereField("userId", isEqualTo: userId)
            .whereField("artistId", isEqualTo: artistId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let documents = snapshot?.documents, !documents.isEmpty {
                    completion(.failure(NSError(
                        domain: "ClaimError",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "You already have a pending claim for this profile"]
                    )))
                    return
                }
                
                // Create new claim request
                let request = ClaimRequest(
                    id: UUID().uuidString,
                    artistId: artistId,
                    userId: userId,
                    userEmail: userEmail,
                    userName: userName,
                    verificationNote: verificationNote,
                    instagramHandle: instagramHandle,
                    status: .pending,
                    createdAt: Date(),
                    reviewedAt: nil,
                    reviewedBy: nil,
                    rejectionReason: nil
                )
                
                self.db.collection("claimRequests").document().setData(request.toFirestoreData()) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
    }
    
    // MARK: - Cleanup
    
    func stopListening() {
        postsListener?.remove()
    }
    
    /// Fetch posts for a specific user (e.g. for Profile View)
    func fetchPosts(forUserId userId: String) {
        isLoading = true
        errorMessage = nil
        
        db.collection("posts")
            .whereField("artistId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    print("Error fetching user posts: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.posts = []
                    return
                }
                
                self.posts = documents.compactMap { Post(document: $0) }
            }
    }
    
    deinit {
        stopListening()
    }
}

// MARK: - Admin Functions (for uploading data)

extension FeedService {
    
    /// Upload a new artist profile
    func uploadArtist(_ artist: Artist, completion: @escaping (Result<String, Error>) -> Void) {
        let docRef = db.collection("artists").document()
        var artistData = artist.toFirestoreData()
        artistData["usernameLower"] = artist.username.lowercased()
        artistData["fullNameLower"] = artist.fullName.lowercased()
        
        docRef.setData(artistData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(docRef.documentID))
            }
        }
    }
    
    /// Upload a new post
    func uploadPost(_ post: Post, completion: @escaping (Result<String, Error>) -> Void) {
        let docRef = db.collection("posts").document()
        
        docRef.setData(post.toFirestoreData()) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(docRef.documentID))
            }
        }
    }
    
    /// Batch upload multiple artists
    func batchUploadArtists(_ artists: [Artist], completion: @escaping (Result<Void, Error>) -> Void) {
        let batch = db.batch()
        
        for artist in artists {
            let docRef = db.collection("artists").document()
            var artistData = artist.toFirestoreData()
            artistData["usernameLower"] = artist.username.lowercased()
            artistData["fullNameLower"] = artist.fullName.lowercased()
            batch.setData(artistData, forDocument: docRef)
        }
        
        batch.commit { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    /// Batch upload multiple posts
    func batchUploadPosts(_ posts: [Post], completion: @escaping (Result<Void, Error>) -> Void) {
        let batch = db.batch()
        
        for post in posts {
            let docRef = db.collection("posts").document()
            batch.setData(post.toFirestoreData(), forDocument: docRef)
        }
        
        batch.commit { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // 1. Upload Image to Firebase Storage
    func uploadImage(image: UIImage, path: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Compression: 0.5 is a good balance of quality vs speed
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            completion(.failure(NSError(domain: "ImageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])))
            return
        }
        
        let ref = Storage.storage().reference().child(path)
        
        ref.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            ref.downloadURL { url, error in
                if let url = url {
                    completion(.success(url.absoluteString))
                } else {
                    completion(.failure(error ?? NSError(domain: "URLError", code: -1, userInfo: nil)))
                }
            }
        }
    }

    // 2. Upload Post Data to Firestore
    func uploadPost(_ post: Post, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            let _ = try db.collection("posts").addDocument(from: post)
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
}
