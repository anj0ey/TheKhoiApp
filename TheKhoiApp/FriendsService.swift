//
//  FriendsService.swift
//  TheKhoiApp
//
//  Service for managing friend relationships
//

import Foundation
import FirebaseFirestore

// MARK: - Friend Model
struct Friend: Identifiable, Codable {
    let id: String
    let fullName: String
    let username: String
    let profileImageURL: String?
    let addedAt: Date
    
    init(id: String, fullName: String, username: String, profileImageURL: String?, addedAt: Date = Date()) {
        self.id = id
        self.fullName = fullName
        self.username = username
        self.profileImageURL = profileImageURL
        self.addedAt = addedAt
    }
    
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        self.id = document.documentID
        self.fullName = data["fullName"] as? String ?? ""
        self.username = data["username"] as? String ?? ""
        self.profileImageURL = data["profileImageURL"] as? String
        self.addedAt = (data["addedAt"] as? Timestamp)?.dateValue() ?? Date()
    }
    
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "fullName": fullName,
            "username": username,
            "addedAt": Timestamp(date: addedAt)
        ]
        if let profileImageURL = profileImageURL {
            data["profileImageURL"] = profileImageURL
        }
        return data
    }
}

// MARK: - Friends Service
class FriendsService: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var isLoading = false
    @Published var friendIds: Set<String> = []
    
    private let db = Firestore.firestore()
    private var friendsListener: ListenerRegistration?
    
    // MARK: - Listen to Friends
    
    func listenToFriends(userId: String) {
        friendsListener?.remove()
        isLoading = true
        
        friendsListener = db.collection("users")
            .document(userId)
            .collection("friends")
            .order(by: "fullName")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    print("Error listening to friends: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.friends = []
                    self.friendIds = []
                    return
                }
                
                self.friends = documents.compactMap { Friend(document: $0) }
                self.friendIds = Set(self.friends.map { $0.id })
            }
    }
    
    // MARK: - Add Friend
    
    func addFriend(
        currentUserId: String,
        friend: Friend,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let friendRef = db.collection("users")
            .document(currentUserId)
            .collection("friends")
            .document(friend.id)
        
        friendRef.setData(friend.toFirestoreData()) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Remove Friend
    
    func removeFriend(
        currentUserId: String,
        friendId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        db.collection("users")
            .document(currentUserId)
            .collection("friends")
            .document(friendId)
            .delete { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
    }
    
    // MARK: - Check if User is Friend
    
    func isFriend(userId: String) -> Bool {
        return friendIds.contains(userId)
    }
    
    // MARK: - Fetch Friends (One-time)
    
    func fetchFriends(userId: String, completion: @escaping ([Friend]) -> Void) {
        db.collection("users")
            .document(userId)
            .collection("friends")
            .order(by: "fullName")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching friends: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                let friends = snapshot?.documents.compactMap { Friend(document: $0) } ?? []
                completion(friends)
            }
    }
    
    // MARK: - Search Friends
    
    func searchFriends(query: String) -> [Friend] {
        guard !query.isEmpty else { return friends }
        
        let lowercased = query.lowercased()
        return friends.filter {
            $0.fullName.lowercased().contains(lowercased) ||
            $0.username.lowercased().contains(lowercased)
        }
    }
    
    // MARK: - Cleanup
    
    func stopListening() {
        friendsListener?.remove()
    }
    
    deinit {
        stopListening()
    }
}
