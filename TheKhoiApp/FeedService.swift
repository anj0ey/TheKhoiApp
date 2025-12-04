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
    @Published var userPosts: [Post] = []  // Posts for the current user's profile
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
    
    /// Fetch posts for a specific user (stores in userPosts for profile view)
    func fetchUserPosts(userId: String) {
        guard !userId.isEmpty else {
            userPosts = []
            return
        }
        
        db.collection("posts")
            .whereField("artistId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching user posts: \(error.localizedDescription)")
                    self.userPosts = []
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.userPosts = []
                    return
                }
                
                self.userPosts = documents.compactMap { Post(document: $0) }
            }
    }
    
    // MARK: - Save Count
    
    /// Update the saveCount for a post (increment or decrement)
    func updateSaveCount(postId: String, increment: Bool) {
        let postRef = db.collection("posts").document(postId)
        let change: Int64 = increment ? 1 : -1
        
        postRef.updateData([
            "saveCount": FieldValue.increment(change)
        ]) { error in
            if let error = error {
                print("Error updating save count: \(error.localizedDescription)")
            } else {
                // Update local posts array to reflect change immediately
                if let index = self.posts.firstIndex(where: { $0.id == postId }) {
                    let newCount = max(0, self.posts[index].saveCount + Int(change))
                    self.posts[index] = Post(
                        id: self.posts[index].id,
                        artistId: self.posts[index].artistId,
                        artistName: self.posts[index].artistName,
                        artistHandle: self.posts[index].artistHandle,
                        artistProfileImageURL: self.posts[index].artistProfileImageURL,
                        imageURL: self.posts[index].imageURL,
                        imageHeight: self.posts[index].imageHeight,
                        tag: self.posts[index].tag,
                        caption: self.posts[index].caption,
                        saveCount: newCount,
                        createdAt: self.posts[index].createdAt
                    )
                }
            }
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
