//
//  CommentService.swift
//  TheKhoiApp
//
//  Service for managing post comments in Firebase
//

import Foundation
import FirebaseFirestore

class CommentService: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var commentsListener: ListenerRegistration?
    
    // MARK: - Fetch Comments for Post
    
    func fetchComments(forPostId postId: String) {
        isLoading = true
        
        commentsListener?.remove()
        
        commentsListener = db.collection("comments")
            .whereField("postId", isEqualTo: postId)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("Error fetching comments: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self?.comments = []
                    return
                }
                
                self?.comments = documents.compactMap { Comment.fromFirestore(document: $0) }
            }
    }
    
    // MARK: - Add Comment
    
    func addComment(
        text: String,
        postId: String,
        authorId: String,
        authorName: String,
        authorUsername: String,
        authorProfileImageURL: String?,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let comment = Comment(
            text: text,
            authorId: authorId,
            authorName: authorName,
            authorUsername: authorUsername,
            authorProfileImageURL: authorProfileImageURL,
            postId: postId
        )
        
        let docRef = db.collection("comments").document()
        var commentData = comment
        commentData.id = docRef.documentID
        
        docRef.setData(commentData.toFirestoreData()) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                // Update comment count on the post
                self.incrementCommentCount(postId: postId)
                completion(.success(docRef.documentID))
            }
        }
    }
    
    // MARK: - Delete Comment
    
    func deleteComment(commentId: String, postId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("comments").document(commentId).delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                // Decrement comment count on the post
                self.decrementCommentCount(postId: postId)
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Update Comment Count
    
    private func incrementCommentCount(postId: String) {
        db.collection("posts").document(postId).updateData([
            "commentCount": FieldValue.increment(Int64(1))
        ]) { error in
            if let error = error {
                print("Error incrementing comment count: \(error)")
            }
        }
    }
    
    private func decrementCommentCount(postId: String) {
        db.collection("posts").document(postId).updateData([
            "commentCount": FieldValue.increment(Int64(-1))
        ]) { error in
            if let error = error {
                print("Error decrementing comment count: \(error)")
            }
        }
    }
    
    // MARK: - Get Comment Count
    
    func getCommentCount(postId: String, completion: @escaping (Int) -> Void) {
        db.collection("comments")
            .whereField("postId", isEqualTo: postId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error getting comment count: \(error)")
                    completion(0)
                    return
                }
                
                completion(snapshot?.documents.count ?? 0)
            }
    }
    
    // MARK: - Cleanup
    
    func removeListener() {
        commentsListener?.remove()
    }
    
    deinit {
        removeListener()
    }
}
