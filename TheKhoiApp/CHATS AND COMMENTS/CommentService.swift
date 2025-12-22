//
//  CommentService.swift
//  TheKhoiApp
//
//  Service for managing post comments in Firebase with push notifications
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
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
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
                    
                    // Parse comments and sort locally by createdAt (oldest first)
                    let fetchedComments = documents.compactMap { Comment.fromFirestore(document: $0) }
                    self?.comments = fetchedComments.sorted { $0.createdAt < $1.createdAt }
                }
            }
    }
    
    // MARK: - Add Comment with Notification
    
    func addComment(
        text: String,
        postId: String,
        postOwnerId: String,
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
        
        docRef.setData(commentData.toFirestoreData()) { [weak self] error in
            if let error = error {
                completion(.failure(error))
            } else {
                // Update comment count on the post
                self?.incrementCommentCount(postId: postId)
                
                // Send push notification to post owner (if not commenting on own post)
                if postOwnerId != authorId {
                    self?.sendCommentNotification(
                        postOwnerId: postOwnerId,
                        commenterName: authorName,
                        commentPreview: text,
                        postId: postId
                    )
                }
                
                completion(.success(docRef.documentID))
            }
        }
    }
    
    /// Send push notification for new comment
    private func sendCommentNotification(
        postOwnerId: String,
        commenterName: String,
        commentPreview: String,
        postId: String
    ) {
        NotificationService.shared.sendNewCommentNotification(
            postOwnerId: postOwnerId,
            commenterName: commenterName,
            commentPreview: commentPreview,
            postId: postId
        )
    }
    
    // MARK: - Delete Comment
    
    func deleteComment(commentId: String, postId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("comments").document(commentId).delete { [weak self] error in
            if let error = error {
                completion(.failure(error))
            } else {
                // Decrement comment count on the post
                self?.decrementCommentCount(postId: postId)
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
