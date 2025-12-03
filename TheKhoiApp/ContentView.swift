//
//  ContentView.swift
//  TheKhoiApp
//
//  Created by Anjo on 11/6/25.
//

import SwiftUI
import AuthenticationServices
import GoogleSignIn
import FirebaseFirestore
import Combine

// MARK: - Main Entry Point
struct ContentView: View {
    @ObservedObject var authManager: AuthManager

    var body: some View {
        Group {
            if authManager.isCheckingAuth {
                ZStack {
                    KHOIColors.background.ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: KHOIColors.accentBrown))
                }
            } else if authManager.isOnboardingComplete {
                RootView()
                    .environmentObject(authManager)
            } else if authManager.needsProfileSetup {
                ProfileSetupView()
                    .environmentObject(authManager)
            } else {
                OnboardingView()
                    .environmentObject(authManager)
            }
        }
    }
}


// MARK: - Theme & Colors
struct KHOIColors {
    static let background = Color(hex: "F5F1ED")
    static let white = Color(hex: "FFFFFF")
    static let cream = Color(hex: "F9F7F4")
    static let softBrown = Color(hex: "A89080")
    static let accentBrown = Color(hex: "8B7355")
    static let darkText = Color(hex: "2C2420")
    static let mutedText = Color(hex: "8A827C")
    static let cardBackground = Color.white
    static let divider = Color(hex: "E8E3DD")
    static let chipBackground = Color(hex: "EDE8E3")
    static let selectedChip = accentBrown
    
    // NEW: Aliases for new profile views
    static let accent = accentBrown
    static let danger = Color.red
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct KHOITheme {
    static let largeTitle = Font.custom("Switzer-Regular", size: 96)
    static let title = Font.custom("Switzer-Regular", size: 28)
    static let title2 = Font.custom("Switzer-Regular", size: 24)
    static let headline = Font.custom("Switzer-Regular", size: 18)
    static let body = Font.custom("Switzer-Regular", size: 16)
    static let callout = Font.custom("Switzer-Regular", size: 14)
    static let caption = Font.custom("Switzer-Regular", size: 12)
    static let caption2 = Font.custom("Switzer-Regular", size: 10)
    
    // NEW: Additional fonts for profile views
    static let heading2 = Font.custom("Switzer-Regular", size: 22)
    static let heading3 = Font.custom("Switzer-Regular", size: 20)
    static let bodyBold = Font.custom("Switzer-Semibold", size: 16)
    static let captionUppercase = Font.custom("Switzer-Regular", size: 11)

    static let spacing_xs: CGFloat = 4
    static let spacing_sm: CGFloat = 8
    static let spacing_md: CGFloat = 12
    static let spacing_lg: CGFloat = 16
    static let spacing_xl: CGFloat = 24
    static let spacing_xxl: CGFloat = 32
    
    static let cornerRadius_sm: CGFloat = 8
    static let cornerRadius_md: CGFloat = 12
    static let cornerRadius_lg: CGFloat = 16
    static let cornerRadius_pill: CGFloat = 100
    
    // NEW: Alias for consistency
    static let radius_lg: CGFloat = 16
}

// MARK: - Service Category
enum ServiceCategory: String, CaseIterable {
    case all = "All"
    case makeup = "Makeup"
    case hair = "Hair"
    case nails = "Nails"
    case lashes = "Lashes"
    case skin = "Skin"
    case body = "Body"
}

// MARK: - Components
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(KHOITheme.callout)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : KHOIColors.darkText)
                .padding(.horizontal, KHOITheme.spacing_lg)
                .padding(.vertical, KHOITheme.spacing_sm)
                .background(
                    Capsule()
                        .fill(isSelected ? KHOIColors.selectedChip : KHOIColors.chipBackground)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : KHOIColors.divider, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PostCard (Updated for Real Posts)
struct PostCard: View {
    let post: Post
    let width: CGFloat
    let isSaved: Bool
    let onSaveTap: () -> Void
    let onArtistTap: (() -> Void)?
    
    init(
        post: Post,
        width: CGFloat,
        isSaved: Bool,
        onSaveTap: @escaping () -> Void,
        onArtistTap: (() -> Void)? = nil
    ) {
        self.post = post
        self.width = width
        self.isSaved = isSaved
        self.onSaveTap = onSaveTap
        self.onArtistTap = onArtistTap
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: KHOITheme.spacing_sm) {
            // Artist info (tappable)
            Button {
                onArtistTap?()
            } label: {
                HStack(spacing: 6) {
                    // Artist profile image
                    if let profileURL = post.artistProfileImageURL, let url = URL(string: profileURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle().fill(KHOIColors.chipBackground)
                        }
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                    }
                    
                    Text(post.artistHandle)
                        .font(KHOITheme.callout)
                        .fontWeight(.medium)
                        .foregroundColor(KHOIColors.darkText)
                    
                    Text(post.tag)
                        .font(KHOITheme.caption)
                        .foregroundColor(KHOIColors.mutedText)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
            
            // Post Image
            if let url = URL(string: post.imageURL), !post.imageURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(KHOIColors.chipBackground)
                            .frame(width: width, height: post.imageHeight)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: width, height: post.imageHeight)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(KHOIColors.chipBackground)
                            .frame(width: width, height: post.imageHeight)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.title)
                                    .foregroundColor(KHOIColors.mutedText)
                            )
                    @unknown default:
                        Rectangle()
                            .fill(KHOIColors.chipBackground)
                            .frame(width: width, height: post.imageHeight)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md))
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: width, height: post.imageHeight)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundColor(.gray.opacity(0.3))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md))
            }
            
            // Caption
            if let caption = post.caption, !caption.isEmpty {
                Text(caption)
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.darkText)
                    .lineLimit(2)
                    .padding(.horizontal, 4)
            }
            
            // Save button
            HStack(spacing: KHOITheme.spacing_sm) {
                Button(action: onSaveTap) {
                    HStack(spacing: 6) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.caption)
                        Text(isSaved ? "Saved" : "Save")
                            .font(KHOITheme.caption)
                    }
                    .foregroundColor(isSaved ? KHOIColors.accentBrown : KHOIColors.darkText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isSaved ? KHOIColors.accentBrown.opacity(0.15) : KHOIColors.chipBackground)
                    )
                }
                .buttonStyle(.plain)
                
                if post.saveCount > 0 {
                    Text("\(post.saveCount) save\(post.saveCount == 1 ? "" : "s")")
                        .font(KHOITheme.caption)
                        .foregroundColor(KHOIColors.mutedText)
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
    }
}

// MARK: - MasonryGrid
struct MasonryGrid<Content: View, T: Identifiable>: View {
    let items: [T]
    let columns: Int
    let spacing: CGFloat
    let content: (T, CGFloat) -> Content
    
    init(
        items: [T],
        columns: Int = 2,
        spacing: CGFloat = 12,
        @ViewBuilder content: @escaping (T, CGFloat) -> Content
    ) {
        self.items = items
        self.columns = columns
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding: CGFloat = KHOITheme.spacing_lg
            let totalSpacing = CGFloat(columns - 1) * spacing
            let contentWidth = geometry.size.width - (horizontalPadding * 2)
            let columnWidth = (contentWidth - totalSpacing) / CGFloat(columns)
            
            ScrollView {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { columnIndex in
                        LazyVStack(spacing: spacing) {
                            ForEach(itemsForColumn(columnIndex)) { item in
                                content(item, columnWidth)
                            }
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, KHOITheme.spacing_md)
            }
        }
    }
    
    private func itemsForColumn(_ columnIndex: Int) -> [T] {
        items.enumerated()
            .filter { $0.offset % columns == columnIndex }
            .map { $0.element }
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        ZStack {
            KHOIColors.white.ignoresSafeArea()
            
            Image("background")
                .resizable()
                .scaledToFit()
                .offset(y: 300)
                .ignoresSafeArea()
                .zIndex(0)
            
            LinearGradient(
                colors: [Color.white, Color.white.opacity(0)],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
            .zIndex(1)
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: KHOITheme.spacing_md) {
                    Text("KHOI")
                        .font(KHOITheme.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(KHOIColors.darkText)
                        .tracking(2)
                    
                    Text("where beauty finds you.")
                        .font(KHOITheme.title2)
                        .foregroundColor(KHOIColors.mutedText)
                        .tracking(2)
                }
                .padding(.bottom, KHOITheme.spacing_xxl)
                
                VStack(spacing: KHOITheme.spacing_md) {
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            authManager.handleAppleRequest(request)
                        },
                        onCompletion: { result in
                            authManager.handleAppleCompletion(result)
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md))
                    
                    Button {
                        authManager.signInWithGoogle()
                    } label: {
                        HStack(spacing: KHOITheme.spacing_md) {
                            Image(systemName: "globe")
                                .font(.title3)
                            Text("Continue with Google")
                                .font(KHOITheme.headline)
                        }
                        .foregroundColor(KHOIColors.darkText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KHOITheme.spacing_lg)
                        .background(KHOIColors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md)
                                .stroke(KHOIColors.divider, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md))
                    }
                }
                .padding(.horizontal, KHOITheme.spacing_xl)
                
                Text("By pressing on 'Continue with…' you agree to our Privacy Policy and Terms and Conditions")
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.mutedText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, KHOITheme.spacing_xl)
                    .padding(.top, KHOITheme.spacing_lg)
                    .padding(.bottom, KHOITheme.spacing_xxl)
                
                Spacer()
            }
            .zIndex(2)
        }
    }
}

// MARK: - Home View Model
class HomeViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var selectedCategory: ServiceCategory = .all
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var savedPostIDs: Set<String> = []
    
    private let db = Firestore.firestore()
    private var postsListener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadSavedPosts()
        $selectedCategory
            .sink { [weak self] category in
                self?.fetchPosts(category: category)
            }
            .store(in: &cancellables)
    }
    
    func fetchPosts(category: ServiceCategory = .all) {
        isLoading = true
        errorMessage = nil
        postsListener?.remove()
        
        var query: Query = db.collection("posts")
            .order(by: "createdAt", descending: true)
        
        if category != .all {
            query = query.whereField("tag", isEqualTo: category.rawValue)
        }
        
        postsListener = query.limit(to: 50).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.errorMessage = error.localizedDescription
                self.loadMockData()
                return
            }
            
            guard let documents = snapshot?.documents else {
                self.loadMockData()
                return
            }
            
            let fetchedPosts = documents.compactMap { Post(document: $0) }
            
            if fetchedPosts.isEmpty {
                self.loadMockData()
            } else {
                self.posts = fetchedPosts
            }
        }
    }
    
    func selectCategory(_ category: ServiceCategory) {
        selectedCategory = category
    }
    
    var filteredPosts: [Post] { posts }
    
    var savedPosts: [Post] {
        posts.filter { savedPostIDs.contains($0.id) }
    }
    
    func toggleSave(for post: Post) {
        if savedPostIDs.contains(post.id) {
            savedPostIDs.remove(post.id)
            decrementSaveCount(postId: post.id)
        } else {
            savedPostIDs.insert(post.id)
            incrementSaveCount(postId: post.id)
        }
        saveSavedPosts()
    }
    
    func isSaved(_ post: Post) -> Bool {
        savedPostIDs.contains(post.id)
    }
    
    func saveCount(for post: Post) -> Int {
        post.saveCount
    }
    
    private func incrementSaveCount(postId: String) {
        db.collection("posts").document(postId).updateData([
            "saveCount": FieldValue.increment(Int64(1))
        ])
    }
    
    private func decrementSaveCount(postId: String) {
        db.collection("posts").document(postId).updateData([
            "saveCount": FieldValue.increment(Int64(-1))
        ])
    }
    
    private func saveSavedPosts() {
        UserDefaults.standard.set(Array(savedPostIDs), forKey: "savedPostIDs")
    }
    
    private func loadSavedPosts() {
        if let array = UserDefaults.standard.array(forKey: "savedPostIDs") as? [String] {
            savedPostIDs = Set(array)
        }
    }
    
    private func loadMockData() {
        let mockPosts: [Post] = [
            Post(id: "mock1", artistId: "artist1", artistName: "Jasmine Li", artistHandle: "@mua_jas", artistProfileImageURL: nil, imageURL: "", imageHeight: 280, tag: "Makeup", caption: nil, saveCount: 0, createdAt: Date()),
            Post(id: "mock2", artistId: "artist2", artistName: "Maya Chen", artistHandle: "@mayabeauty", artistProfileImageURL: nil, imageURL: "", imageHeight: 320, tag: "Makeup", caption: nil, saveCount: 0, createdAt: Date()),
            Post(id: "mock3", artistId: "artist3", artistName: "Sofia Martinez", artistHandle: "@sofiaglam", artistProfileImageURL: nil, imageURL: "", imageHeight: 240, tag: "Nails", caption: nil, saveCount: 0, createdAt: Date()),
            Post(id: "mock4", artistId: "artist4", artistName: "Aisha Williams", artistHandle: "@aisha_mua", artistProfileImageURL: nil, imageURL: "", imageHeight: 300, tag: "Lashes", caption: nil, saveCount: 0, createdAt: Date()),
            Post(id: "mock5", artistId: "artist5", artistName: "Emma Thompson", artistHandle: "@emmaartistry", artistProfileImageURL: nil, imageURL: "", imageHeight: 260, tag: "Skin", caption: nil, saveCount: 0, createdAt: Date()),
            Post(id: "mock6", artistId: "artist6", artistName: "Priya Patel", artistHandle: "@priya_beauty", artistProfileImageURL: nil, imageURL: "", imageHeight: 340, tag: "Hair", caption: nil, saveCount: 0, createdAt: Date()),
            Post(id: "mock7", artistId: "artist7", artistName: "Luna Rodriguez", artistHandle: "@luna_makeup", artistProfileImageURL: nil, imageURL: "", imageHeight: 220, tag: "Body", caption: nil, saveCount: 0, createdAt: Date()),
            Post(id: "mock8", artistId: "artist8", artistName: "Zara Kim", artistHandle: "@zara_mua", artistProfileImageURL: nil, imageURL: "", imageHeight: 290, tag: "Lashes", caption: nil, saveCount: 0, createdAt: Date()),
        ]
        
        if selectedCategory == .all {
            posts = mockPosts
        } else {
            posts = mockPosts.filter { $0.tag == selectedCategory.rawValue }
        }
    }
    
    func stopListening() {
        postsListener?.remove()
    }
    
    deinit {
        stopListening()
    }
}

// MARK: - Home View
struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var searchResults: [SearchResult] = []
    @State private var selectedArtistId: String?
    @State private var showArtistProfile = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(KHOIColors.mutedText)
                        
                        TextField("Search people, services...", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit { performSearch() }
                            .onChange(of: searchText) { oldValue, newValue in
                                if newValue.isEmpty {
                                    isSearching = false
                                    hasSearched = false
                                    searchResults = []
                                }
                            }
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                isSearching = false
                                hasSearched = false
                                searchResults = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(KHOIColors.mutedText)
                            }
                        }
                    }
                    .padding()
                    .background(KHOIColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md))
                    .padding(.horizontal)
                    .padding(.top, KHOITheme.spacing_sm)
                    
                    if isSearching || hasSearched {
                        SearchResultsView(
                            isSearching: isSearching,
                            searchResults: searchResults,
                            searchText: searchText,
                            onArtistTap: { artistId in
                                selectedArtistId = artistId
                                showArtistProfile = true
                            }
                        )
                    } else {
                        homeContent
                    }
                }
            }
            .navigationDestination(isPresented: $showArtistProfile) {
                if let artistId = selectedArtistId {
                    ArtistProfileDestination(artistId: artistId)
                }
            }
        }
    }
    
    private var homeContent: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: KHOITheme.spacing_sm) {
                    ForEach(ServiceCategory.allCases, id: \.self) { category in
                        FilterChip(
                            title: category.rawValue,
                            isSelected: viewModel.selectedCategory == category
                        ) {
                            viewModel.selectCategory(category)
                        }
                    }
                }
                .padding(.horizontal, KHOITheme.spacing_lg)
                .padding(.vertical, KHOITheme.spacing_md)
            }
            
            HStack(spacing: KHOITheme.spacing_sm) {
                Text("DISCOVER")
                    .font(KHOITheme.headline)
                    .foregroundColor(KHOIColors.mutedText)
                    .tracking(2)
                
                Image(systemName: "globe")
                    .foregroundColor(KHOIColors.mutedText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
            
            MasonryGrid(
                items: viewModel.filteredPosts,
                columns: 2,
                spacing: KHOITheme.spacing_md
            ) { post, width in
                PostCard(
                    post: post,
                    width: width,
                    isSaved: viewModel.isSaved(post),
                    onSaveTap: { viewModel.toggleSave(for: post) },
                    onArtistTap: {
                        selectedArtistId = post.artistId
                        showArtistProfile = true
                    }
                )
            }
        }
    }
    
    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        
        isSearching = true
        hasSearched = true
        searchResults = []
        
        let searchLower = query.lowercased()
        
        let matchingCategories = ServiceCategory.allCases.filter { category in
            category != .all && category.rawValue.lowercased().contains(searchLower)
        }
        
        let categoryResults = matchingCategories.map { category in
            SearchResult(
                id: "category-\(category.rawValue)",
                type: .service,
                title: category.rawValue,
                subtitle: "Service category",
                imageURL: nil
            )
        }
        searchResults.append(contentsOf: categoryResults)
        
        let db = Firestore.firestore()
        
        // Search artists
        db.collection("artists")
            .whereField("usernameLower", isGreaterThanOrEqualTo: searchLower)
            .whereField("usernameLower", isLessThanOrEqualTo: searchLower + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    let artists = documents.compactMap { doc -> SearchResult? in
                        let data = doc.data()
                        guard let username = data["username"] as? String,
                              let fullName = data["fullName"] as? String else { return nil }
                        
                        return SearchResult(
                            id: doc.documentID,
                            type: .artist,
                            title: fullName,
                            subtitle: "@\(username)",
                            imageURL: data["profileImageURL"] as? String
                        )
                    }
                    searchResults.append(contentsOf: artists)
                }
                isSearching = false
            }
    }
}

// MARK: - Artist Profile Destination
struct ArtistProfileDestination: View {
    let artistId: String
    @State private var artist: Artist?
    @State private var isLoading = true
    
    private let db = Firestore.firestore()
    
    var body: some View {
        Group {
            if isLoading {
                ZStack {
                    KHOIColors.background.ignoresSafeArea()
                    ProgressView()
                }
            } else if let artist = artist {
                ArtistProfileView(artist: artist)
            } else {
                ZStack {
                    KHOIColors.background.ignoresSafeArea()
                    Text("Artist not found")
                        .foregroundColor(KHOIColors.mutedText)
                }
            }
        }
        .onAppear { fetchArtist() }
    }
    
    private func fetchArtist() {
        db.collection("artists").document(artistId).getDocument { snapshot, error in
            isLoading = false
            if let snapshot = snapshot {
                artist = Artist(document: snapshot)
            }
        }
    }
}

// MARK: - Search Models
struct SearchResult: Identifiable {
    let id: String
    let type: ResultType
    let title: String
    let subtitle: String
    let imageURL: String?
    
    enum ResultType {
        case user
        case service
        case artist
    }
}

// MARK: - Search Results View
struct SearchResultsView: View {
    let isSearching: Bool
    let searchResults: [SearchResult]
    let searchText: String
    var onArtistTap: ((String) -> Void)?
    
    var body: some View {
        if isSearching {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: KHOIColors.accentBrown))
            Spacer()
        } else if searchResults.isEmpty && !searchText.isEmpty {
            Spacer()
            VStack(spacing: KHOITheme.spacing_md) {
                Image(systemName: "magnifyingglass")
                    .font(.largeTitle)
                    .foregroundColor(KHOIColors.mutedText)
                Text("No results found")
                    .font(KHOITheme.body)
                    .foregroundColor(KHOIColors.mutedText)
            }
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(searchResults) { result in
                        Button {
                            if result.type == .artist {
                                onArtistTap?(result.id)
                            }
                        } label: {
                            SearchResultRow(result: result)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, KHOITheme.spacing_sm)
                        
                        Divider().padding(.horizontal)
                    }
                }
                .padding(.top, KHOITheme.spacing_md)
            }
        }
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let result: SearchResult
    
    var iconName: String {
        switch result.type {
        case .user: return "person.fill"
        case .service: return "sparkles"
        case .artist: return "paintbrush.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: KHOITheme.spacing_md) {
            if let imageURL = result.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(KHOIColors.chipBackground)
                        .overlay(Image(systemName: iconName).foregroundColor(KHOIColors.mutedText))
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(KHOIColors.chipBackground)
                    .frame(width: 50, height: 50)
                    .overlay(Image(systemName: iconName).foregroundColor(KHOIColors.mutedText))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(KHOITheme.headline)
                    .foregroundColor(KHOIColors.darkText)
                
                Text(result.subtitle)
                    .font(KHOITheme.callout)
                    .foregroundColor(KHOIColors.mutedText)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(KHOIColors.mutedText)
        }
    }
}

// MARK: - Appointments
struct Appointments: View {
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background.ignoresSafeArea()
                Text("APPOINTMENTS")
                    .font(KHOITheme.headline)
                    .foregroundColor(KHOIColors.mutedText)
                    .tracking(2)
            }
            .navigationTitle("Appointments")
        }
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: KHOITheme.spacing_md) {
                        if let user = authManager.currentUser {
                            VStack(spacing: 4) {
                                Text("@\(user.username)")
                                    .font(KHOITheme.title2)
                                    .foregroundColor(KHOIColors.darkText)

                                if !user.bio.isEmpty {
                                    Text(user.bio)
                                        .font(KHOITheme.body)
                                        .foregroundColor(KHOIColors.mutedText)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, KHOITheme.spacing_xl)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, KHOITheme.spacing_xl)
                        } else {
                            Text("No profile yet")
                                .font(KHOITheme.body)
                                .foregroundColor(KHOIColors.mutedText)
                                .frame(maxWidth: .infinity)
                                .padding(.top, KHOITheme.spacing_xl)
                        }

                        Text("My Collection")
                            .font(KHOITheme.headline)
                            .foregroundColor(KHOIColors.darkText)
                            .padding(.horizontal, KHOITheme.spacing_lg)
                            .padding(.top, KHOITheme.spacing_lg)

                        if viewModel.savedPosts.isEmpty {
                            Text("Save looks you love from Discover to see them here.")
                                .font(KHOITheme.body)
                                .foregroundColor(KHOIColors.mutedText)
                                .padding(.horizontal, KHOITheme.spacing_lg)
                                .padding(.top, KHOITheme.spacing_md)
                        } else {
                            MasonryGrid(
                                items: viewModel.savedPosts,
                                columns: 2,
                                spacing: KHOITheme.spacing_md
                            ) { post, width in
                                PostCard(
                                    post: post,
                                    width: width,
                                    isSaved: viewModel.isSaved(post),
                                    onSaveTap: { viewModel.toggleSave(for: post) }
                                )
                            }
                        }

                        Button(action: { authManager.logOut() }) {
                            Text("Log Out")
                                .foregroundColor(.red)
                                .font(KHOITheme.body)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(KHOIColors.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md))
                                .padding(.horizontal)
                        }
                        .padding(.top, KHOITheme.spacing_xl)
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}

// MARK: - Root View (Tab Bar)
struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab = 0
    @State private var showCreatePost = false
    
    var body: some View {
        TabView(selection: Binding(
            get: { selectedTab },
            set: { newValue in
                // Intercept the "Post" tap (Tag 2) only if in Business Mode
                if authManager.isBusinessMode && newValue == 2 {
                    showCreatePost = true
                } else {
                    selectedTab = newValue
                }
            }
        )) {
            // TAB 0: Discover
            DiscoverView()
                .tabItem { Label("Discover", systemImage: "magnifyingglass") }
                .tag(0)
            
            // TAB 1: Appointments
            AppointmentsView()
                .tabItem { Label("Appointments", systemImage: "calendar") }
                .tag(1)
            
            // MIDDLE TAB: Only for Business Mode
            if authManager.isBusinessMode {
                Text("") // Dummy View
                    .tabItem {
                        Image(systemName: "plus.circle.fill")
                        Text("Post")
                    }
                    .tag(2)
            }
            
            // TAB 3: Chats
            // Note: If Business Mode is OFF, this becomes the 3rd item visually,
            // but we keep the tag distinct (3) to avoid confusion.
            ChatsView()
                .tabItem { Label("Chats", systemImage: "message.fill") }
                .tag(3)
            
            // TAB 4: Profile
            ClientProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(4)
        }
        .tint(KHOIColors.accentBrown)
        .sheet(isPresented: $showCreatePost) {
            CreatePostView()
                .environmentObject(authManager)
        }
    }
}

#Preview {
    ContentView(authManager: AuthManager())
}
