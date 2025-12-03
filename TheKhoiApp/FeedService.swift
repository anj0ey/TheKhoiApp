//
//  FeedService.swift
//  TheKhoiApp
//
//  Service to fetch posts, upload images, and manage data.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit // Needed for UIImage

class FeedService: ObservableObject {
    @Published var posts: [Post] = []
    @Published var artists: [Artist] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var postsListener: ListenerRegistration?
    
    // MARK: - Fetching Posts
    
    /// Fetch all posts for the Discover feed (with optional category filter)
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
    
    /// Fetch posts for a specific user (For Client Profile)
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
    
    // MARK: - Uploading
    
    /// Upload an image to Firebase Storage and get the URL
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

    /// Upload a single Post to Firestore
    /// Returns: The new Document ID (String)
    func uploadPost(_ post: Post, completion: @escaping (Result<String, Error>) -> Void) {
        do {
            let docRef = try db.collection("posts").addDocument(from: post)
            completion(.success(docRef.documentID))
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - Admin / Batch Utilities
    
    /// Batch upload multiple artists (Used by AdminUploadView if needed)
    func batchUploadArtists(_ artists: [Artist], completion: @escaping (Result<Void, Error>) -> Void) {
        let batch = db.batch()
        
        for artist in artists {
            let docRef = db.collection("artists").document()
            var artistData = artist.toFirestoreData()
            // Add search helpers
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
    
    /// Batch upload multiple posts (Used by AdminUploadView if needed)
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
    
    // MARK: - Business Logic
    
    /// Submit a request to claim an artist profile
    func submitClaimRequest(artistId: String, userId: String, userEmail: String, userName: String, verificationNote: String, instagramHandle: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        
        let data: [String: Any] = [
            "artistId": artistId,
            "userId": userId,
            "userEmail": userEmail,
            "userName": userName,
            "verificationNote": verificationNote,
            "instagramHandle": instagramHandle ?? "",
            "status": "pending",
            "createdAt": Timestamp(date: Date())
        ]
        
        // Add to a "claim_requests" collection
        db.collection("claim_requests").addDocument(data: data) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Single Uploads

    /// Upload a single Artist to Firestore
    func uploadArtist(_ artist: Artist, completion: @escaping (Result<String, Error>) -> Void) {
        // If the artist struct has an ID, use it. Otherwise create a new document.
        let docRef = artist.id.isEmpty ? db.collection("artists").document() : db.collection("artists").document(artist.id)
        
        var data = artist.toFirestoreData()
        // Add search helpers
        data["usernameLower"] = artist.username.lowercased()
        data["fullNameLower"] = artist.fullName.lowercased()
        
        docRef.setData(data) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(docRef.documentID))
            }
        }
    }
    
    // MARK: - Fetch Single Artist
    
    /// Fetch a single artist by ID (Used in AdminUploadView to attach names to posts)
    func fetchArtist(artistId: String, completion: @escaping (Artist?) -> Void) {
        db.collection("artists").document(artistId).getDocument { snapshot, error in
            // 1. Check if document exists
            guard let document = snapshot, document.exists else {
                print("❌ Artist not found: \(artistId)")
                completion(nil)
                return
            }
            
            // 2. Try to decode it
            do {
                let artist = try document.data(as: Artist.self)
                completion(artist)
            } catch {
                print("❌ Error decoding artist: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
}
