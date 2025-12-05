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
    @Published var savedPosts: [Post] = [] // Posts the user has saved
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
    
    // MARK: - Save Posts (Per-User)
    
    /// Toggle save status for a post - stores in user's savedPosts subcollection and updates post saveCount
    func toggleSavePost(postId: String, userId: String, isSaving: Bool) {
        let userSavedRef = db.collection("users").document(userId).collection("savedPosts").document(postId)
        let postRef = db.collection("posts").document(postId)
        
        if isSaving {
            // Add to user's saved posts
            userSavedRef.setData([
                "postId": postId,
                "savedAt": Timestamp(date: Date())
            ]) { error in
                if let error = error {
                    print("Error saving post: \(error.localizedDescription)")
                }
            }
            
            // Increment post's saveCount
            postRef.updateData([
                "saveCount": FieldValue.increment(Int64(1))
            ]) { [weak self] error in
                if error == nil {
                    self?.updateLocalPostSaveCount(postId: postId, increment: true)
                }
            }
        } else {
            // Remove from user's saved posts
            userSavedRef.delete { error in
                if let error = error {
                    print("Error unsaving post: \(error.localizedDescription)")
                }
            }
            
            // Decrement post's saveCount
            postRef.updateData([
                "saveCount": FieldValue.increment(Int64(-1))
            ]) { [weak self] error in
                if error == nil {
                    self?.updateLocalPostSaveCount(postId: postId, increment: false)
                }
            }
        }
    }
    
    /// Fetch all post IDs that a user has saved
    func fetchUserSavedPosts(userId: String, completion: @escaping (Set<String>) -> Void) {
        db.collection("users").document(userId).collection("savedPosts")
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching saved posts: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                let postIds = snapshot?.documents.compactMap { $0.documentID } ?? []
                let postIdSet = Set(postIds)
                completion(postIdSet)
                
                // Also fetch the actual post data for the profile view
                self?.fetchSavedPostsData(postIds: Array(postIdSet))
            }
    }
    
    /// Fetch actual Post objects for saved post IDs
    func fetchSavedPostsData(postIds: [String]) {
        guard !postIds.isEmpty else {
            DispatchQueue.main.async {
                self.savedPosts = []
            }
            return
        }
        
        // Firestore 'in' query limited to 10 items, so batch if needed
        let batches = postIds.chunked(into: 10)
        var allPosts: [Post] = []
        let group = DispatchGroup()
        
        for batch in batches {
            group.enter()
            db.collection("posts")
                .whereField(FieldPath.documentID(), in: batch)
                .getDocuments { snapshot, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("Error fetching saved post data: \(error.localizedDescription)")
                        return
                    }
                    
                    let posts = snapshot?.documents.compactMap { Post(document: $0) } ?? []
                    allPosts.append(contentsOf: posts)
                }
        }
        
        group.notify(queue: .main) {
            self.savedPosts = allPosts
        }
    }
    
    /// Update local posts array saveCount for immediate UI feedback
    private func updateLocalPostSaveCount(postId: String, increment: Bool) {
        DispatchQueue.main.async {
            if let index = self.posts.firstIndex(where: { $0.id == postId }) {
                let change = increment ? 1 : -1
                let newCount = max(0, self.posts[index].saveCount + change)
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

// MARK: - Array Extension for batching
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
