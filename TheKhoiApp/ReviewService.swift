//
//  ReviewService.swift
//  TheKhoiApp
//
//  Service for managing reviews in Firebase
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit

class ReviewService: ObservableObject {
    @Published var reviews: [Review] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var reviewStats: ReviewStats = ReviewStats()
    
    private let db = Firestore.firestore()
    private var reviewsListener: ListenerRegistration?
    
    // MARK: - Fetch Reviews for Artist
    
    func fetchReviews(forArtistId artistId: String) {
        isLoading = true
        
        reviewsListener?.remove()
        
        reviewsListener = db.collection("reviews")
            .whereField("artistId", isEqualTo: artistId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("Error fetching reviews: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self?.reviews = []
                    self?.reviewStats = ReviewStats()
                    return
                }
                
                self?.reviews = documents.compactMap { Review.fromFirestore(document: $0) }
                self?.reviewStats = ReviewStats.calculate(from: self?.reviews ?? [])
            }
    }
    
    // MARK: - Check if User Can Review
    
    /// Check if user has had a completed/confirmed appointment with this artist
    func checkCanReview(
        userId: String,
        artistId: String,
        completion: @escaping (Bool, [Appointment]) -> Void
    ) {
        db.collection("appointments")
            .whereField("clientId", isEqualTo: userId)
            .whereField("artistId", isEqualTo: artistId)
            .whereField("status", in: ["confirmed", "completed"])
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error checking review eligibility: \(error)")
                    completion(false, [])
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    completion(false, [])
                    return
                }
                
                let appointments = documents.compactMap { Appointment.fromFirestore(document: $0) }
                completion(true, appointments)
            }
    }
    
    /// Check if user has already reviewed this artist
    func hasUserReviewed(
        userId: String,
        artistId: String,
        completion: @escaping (Bool) -> Void
    ) {
        db.collection("reviews")
            .whereField("authorId", isEqualTo: userId)
            .whereField("artistId", isEqualTo: artistId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error checking existing review: \(error)")
                    completion(false)
                    return
                }
                
                let hasReviewed = !(snapshot?.documents.isEmpty ?? true)
                completion(hasReviewed)
            }
    }
    
    // MARK: - Submit Review
    
    func submitReview(_ review: Review, completion: @escaping (Result<String, Error>) -> Void) {
        isLoading = true
        
        let docRef = db.collection("reviews").document()
        var reviewData = review
        reviewData.id = docRef.documentID
        
        docRef.setData(reviewData.toFirestoreData()) { [weak self] error in
            self?.isLoading = false
            
            if let error = error {
                self?.errorMessage = error.localizedDescription
                completion(.failure(error))
            } else {
                // Update artist's review count and rating
                self?.updateArtistReviewStats(artistId: review.artistId)
                completion(.success(docRef.documentID))
            }
        }
    }
    
    // MARK: - Upload Review Image
    
    func uploadReviewImage(
        image: UIImage,
        reviewId: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let imageData = image.jpegData(compressionQuality: 0.6) else {
            completion(.failure(NSError(domain: "ImageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])))
            return
        }
        
        let imageId = UUID().uuidString
        let path = "review_images/\(reviewId)/\(imageId).jpg"
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
    
    // MARK: - Upload Multiple Images
    
    func uploadReviewImages(
        images: [UIImage],
        reviewId: String,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        guard !images.isEmpty else {
            completion(.success([]))
            return
        }
        
        var uploadedURLs: [String] = []
        let group = DispatchGroup()
        var uploadError: Error?
        
        for image in images {
            group.enter()
            uploadReviewImage(image: image, reviewId: reviewId) { result in
                switch result {
                case .success(let url):
                    uploadedURLs.append(url)
                case .failure(let error):
                    uploadError = error
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if let error = uploadError {
                completion(.failure(error))
            } else {
                completion(.success(uploadedURLs))
            }
        }
    }
    
    // MARK: - Update Artist Stats
    
    private func updateArtistReviewStats(artistId: String) {
        // Fetch all reviews for this artist and calculate new stats
        db.collection("reviews")
            .whereField("artistId", isEqualTo: artistId)
            .getDocuments { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                let reviews = documents.compactMap { Review.fromFirestore(document: $0) }
                let stats = ReviewStats.calculate(from: reviews)
                
                // Update artist document with new review stats
                self?.db.collection("artists").document(artistId).updateData([
                    "reviewCount": stats.totalReviews,
                    "rating": stats.averageRating
                ]) { error in
                    if let error = error {
                        print("Error updating artist review stats: \(error)")
                    }
                }
            }
    }
    
    // MARK: - Delete Review
    
    func deleteReview(reviewId: String, artistId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("reviews").document(reviewId).delete { [weak self] error in
            if let error = error {
                completion(.failure(error))
            } else {
                // Update artist stats after deletion
                self?.updateArtistReviewStats(artistId: artistId)
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Get Services User Has Received
    
    func getServicesReceived(
        userId: String,
        artistId: String,
        completion: @escaping ([String]) -> Void
    ) {
        db.collection("appointments")
            .whereField("clientId", isEqualTo: userId)
            .whereField("artistId", isEqualTo: artistId)
            .whereField("status", in: ["confirmed", "completed"])
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching services: \(error)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                let services = documents.compactMap { doc -> String? in
                    let data = doc.data()
                    return data["serviceName"] as? String
                }
                
                // Return unique services
                completion(Array(Set(services)))
            }
    }
    
    // MARK: - Cleanup
    
    func removeListener() {
        reviewsListener?.remove()
    }
    
    deinit {
        removeListener()
    }
}
