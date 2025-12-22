//
//  SearchService.swift
//  TheKhoiApp
//
//  Handles search across users, artists, and posts
//

import Foundation
import FirebaseFirestore

// MARK: - Search Result Models

struct UserSearchResult: Identifiable {
    let id: String
    let fullName: String
    let username: String
    let profileImageURL: String?
    let isArtist: Bool  // true if from artists collection
}

struct PostSearchResult: Identifiable {
    let id: String
    let imageURL: String
    let artistName: String
    let artistHandle: String
    let tag: String
    let artistId: String
}

// MARK: - Search Service

class SearchService: ObservableObject {
    @Published var userResults: [UserSearchResult] = []
    @Published var postResults: [PostSearchResult] = []
    @Published var isSearching = false
    
    private let db = Firestore.firestore()
    private var searchTask: Task<Void, Never>?
    
    /// Main search function - searches users, artists, and posts
    func search(query: String) {
        // Cancel previous search
        searchTask?.cancel()
        
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Clear results if query is empty
        guard !trimmed.isEmpty else {
            userResults = []
            postResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        // Debounce search
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                self.searchUsers(query: trimmed)
                self.searchPosts(query: trimmed)
            }
        }
    }
    
    /// Search users collection
    private func searchUsers(query: String) {
        let queryUpper = query.prefix(1).uppercased() + query.dropFirst()
        
        // Search by username (lowercase)
        db.collection("users")
            .whereField("usernameLower", isGreaterThanOrEqualTo: query)
            .whereField("usernameLower", isLessThanOrEqualTo: query + "\u{f8ff}")
            .limit(to: 10)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                var results: [UserSearchResult] = []
                
                if let documents = snapshot?.documents {
                    for doc in documents {
                        let data = doc.data()
                        let result = UserSearchResult(
                            id: doc.documentID,
                            fullName: data["fullName"] as? String ?? "",
                            username: data["username"] as? String ?? "",
                            profileImageURL: data["profileImageURL"] as? String,
                            isArtist: false
                        )
                        results.append(result)
                    }
                }
                
                // Also search by fullName
                self.db.collection("users")
                    .whereField("fullNameLower", isGreaterThanOrEqualTo: query)
                    .whereField("fullNameLower", isLessThanOrEqualTo: query + "\u{f8ff}")
                    .limit(to: 10)
                    .getDocuments { snapshot2, error2 in
                        if let documents = snapshot2?.documents {
                            for doc in documents {
                                // Avoid duplicates
                                if !results.contains(where: { $0.id == doc.documentID }) {
                                    let data = doc.data()
                                    let result = UserSearchResult(
                                        id: doc.documentID,
                                        fullName: data["fullName"] as? String ?? "",
                                        username: data["username"] as? String ?? "",
                                        profileImageURL: data["profileImageURL"] as? String,
                                        isArtist: false
                                    )
                                    results.append(result)
                                }
                            }
                        }
                        
                        // Now search artists collection
                        self.searchArtists(query: query, existingResults: results)
                    }
            }
    }
    
    /// Search artists collection
    private func searchArtists(query: String, existingResults: [UserSearchResult]) {
        var results = existingResults
        
        db.collection("artists")
            .whereField("usernameLower", isGreaterThanOrEqualTo: query)
            .whereField("usernameLower", isLessThanOrEqualTo: query + "\u{f8ff}")
            .limit(to: 10)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let documents = snapshot?.documents {
                    for doc in documents {
                        // Avoid duplicates (might be same person in both collections)
                        if !results.contains(where: { $0.id == doc.documentID || $0.username.lowercased() == (doc.data()["username"] as? String ?? "").lowercased() }) {
                            let data = doc.data()
                            let result = UserSearchResult(
                                id: doc.documentID,
                                fullName: data["fullName"] as? String ?? "",
                                username: data["username"] as? String ?? "",
                                profileImageURL: data["profileImageURL"] as? String,
                                isArtist: true
                            )
                            results.append(result)
                        }
                    }
                }
                
                // Search artists by fullName too
                self.db.collection("artists")
                    .whereField("fullNameLower", isGreaterThanOrEqualTo: query)
                    .whereField("fullNameLower", isLessThanOrEqualTo: query + "\u{f8ff}")
                    .limit(to: 10)
                    .getDocuments { snapshot2, error2 in
                        if let documents = snapshot2?.documents {
                            for doc in documents {
                                if !results.contains(where: { $0.id == doc.documentID }) {
                                    let data = doc.data()
                                    let result = UserSearchResult(
                                        id: doc.documentID,
                                        fullName: data["fullName"] as? String ?? "",
                                        username: data["username"] as? String ?? "",
                                        profileImageURL: data["profileImageURL"] as? String,
                                        isArtist: true
                                    )
                                    results.append(result)
                                }
                            }
                        }
                        
                        DispatchQueue.main.async {
                            self.userResults = results
                            self.isSearching = false
                        }
                    }
            }
    }
    
    /// Search posts by tag, caption, or artist name
    private func searchPosts(query: String) {
        var results: [PostSearchResult] = []
        let group = DispatchGroup()
        
        // Check if query matches a category
        let categories = ["skin", "nails", "nail", "makeup", "lashes", "lash", "hair", "brows", "body"]
        let matchedCategory = categories.first { $0.contains(query) || query.contains($0) }
        
        if let category = matchedCategory {
            // Search by tag
            group.enter()
            db.collection("posts")
                .whereField("tag", isEqualTo: category.capitalized)
                .limit(to: 20)
                .getDocuments { snapshot, error in
                    defer { group.leave() }
                    if let documents = snapshot?.documents {
                        for doc in documents {
                            let data = doc.data()
                            let result = PostSearchResult(
                                id: doc.documentID,
                                imageURL: data["imageURL"] as? String ?? "",
                                artistName: data["artistName"] as? String ?? "",
                                artistHandle: data["artistHandle"] as? String ?? "",
                                tag: data["tag"] as? String ?? "",
                                artistId: data["artistId"] as? String ?? ""
                            )
                            results.append(result)
                        }
                    }
                }
        }
        
        // Search by artist name in posts
        group.enter()
        db.collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments { [weak self] snapshot, error in
                defer { group.leave() }
                guard let self = self else { return }
                
                if let documents = snapshot?.documents {
                    for doc in documents {
                        let data = doc.data()
                        let artistName = (data["artistName"] as? String ?? "").lowercased()
                        let artistHandle = (data["artistHandle"] as? String ?? "").lowercased()
                        let caption = (data["caption"] as? String ?? "").lowercased()
                        let tag = (data["tag"] as? String ?? "").lowercased()
                        
                        // Check if query matches
                        if artistName.contains(query) || artistHandle.contains(query) || caption.contains(query) || tag.contains(query) {
                            if !results.contains(where: { $0.id == doc.documentID }) {
                                let result = PostSearchResult(
                                    id: doc.documentID,
                                    imageURL: data["imageURL"] as? String ?? "",
                                    artistName: data["artistName"] as? String ?? "",
                                    artistHandle: data["artistHandle"] as? String ?? "",
                                    tag: data["tag"] as? String ?? "",
                                    artistId: data["artistId"] as? String ?? ""
                                )
                                results.append(result)
                            }
                        }
                    }
                }
            }
        
        group.notify(queue: .main) {
            self.postResults = results
        }
    }
    
    /// Clear all search results
    func clearResults() {
        userResults = []
        postResults = []
        isSearching = false
    }
}
