//
//  ContentView.swift
//  TheKhoiApp
//
//  Created by Anjo on 11/6/25.
//

import SwiftUI
import AuthenticationServices
import GoogleSignIn

// MARK: - Main Entry Point
struct ContentView: View {
    @ObservedObject var authManager: AuthManager

    var body: some View {
        Group {
            if authManager.isCheckingAuth {
                // Show loading while checking auth state
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
}

// MARK: - Models
struct InspoPost: Identifiable {
    let id: UUID
    let imageHeight: CGFloat
    let imageURL: URL?
    let artistName: String
    let artistHandle: String
    let tag: String
    
    init(
        id: UUID = UUID(),
        imageHeight: CGFloat,
        imageURL: URL? = nil,
        artistName: String,
        artistHandle: String,
        tag: String
    ) {
        self.id = id
        self.imageHeight = imageHeight
        self.imageURL = imageURL
        self.artistName = artistName
        self.artistHandle = artistHandle
        self.tag = tag
    }
}

extension InspoPost {
    static let samples: [InspoPost] = [
        InspoPost(imageHeight: 280, artistName: "Jasmine Li", artistHandle: "@mua_jas", tag: "Makeup"),
        InspoPost(imageHeight: 320, artistName: "Maya Chen", artistHandle: "@mayabeauty", tag: "Makeup"),
        InspoPost(imageHeight: 240, artistName: "Sofia Martinez", artistHandle: "@sofiaglam", tag: "Nails"),
        InspoPost(imageHeight: 300, artistName: "Aisha Williams", artistHandle: "@aisha_mua", tag: "Lashes"),
        InspoPost(imageHeight: 260, artistName: "Emma Thompson", artistHandle: "@emmaartistry", tag: "Skin"),
        InspoPost(imageHeight: 340, artistName: "Priya Patel", artistHandle: "@priya_beauty", tag: "Hair"),
        InspoPost(imageHeight: 220, artistName: "Luna Rodriguez", artistHandle: "@luna_makeup", tag: "Body"),
        InspoPost(imageHeight: 290, artistName: "Zara Kim", artistHandle: "@zara_mua", tag: "Lashes"),
        InspoPost(imageHeight: 310, artistName: "Chloe Davis", artistHandle: "@chloebeauty", tag: "Lashes"),
        InspoPost(imageHeight: 270, artistName: "Nadia Ali", artistHandle: "@nadia_artistry", tag: "Nails"),
    ]
}

enum ServiceCategory: String, CaseIterable {
    case all = "All"
    case makeup = "Makeup"
    case hair = "Hair"
    case nails = "Nails"
    case lashes = "Lashes"
    case skin = "Skin"
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

// mock posts until real posts can be built
struct InspoCard: View {
    let post: InspoPost
    let width: CGFloat
    let isSaved: Bool
    let saveCount: Int
    let onSaveTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: KHOITheme.spacing_sm) {
            // Artist info
            HStack(spacing: 3) {
                Text(post.artistHandle)
                    .font(KHOITheme.callout)
                    .fontWeight(.medium)
                    .foregroundColor(KHOIColors.darkText)
                
                Text(post.tag)
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.mutedText)
            }
            .padding(.horizontal, 4)
            
            // Image
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: width, height: post.imageHeight)
                .overlay(
                    AsyncImage(url: post.imageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ZStack {
                            Color.gray.opacity(0.1)
                            Image(systemName: "photo")
                                .font(.title)
                                .foregroundColor(.gray.opacity(0.3))
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md))
            
            // Save button + count
            HStack(spacing: KHOITheme.spacing_sm) {
                Button(action: onSaveTap) {
                    HStack(spacing: 6) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.caption)
                        Text(isSaved ? "Saved" : "Save to Collection")
                            .font(KHOITheme.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isSaved ? KHOIColors.selectedChip.opacity(0.15) : KHOIColors.chipBackground)
                    )
                }
                .buttonStyle(.plain)
                
                if saveCount > 0 {
                    Text("\(saveCount) save\(saveCount == 1 ? "" : "s")")
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
                
                // Logo + Tagline
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
                
                // Auth buttons
                VStack(spacing: KHOITheme.spacing_md) {
                    
                    // Sign in with Apple (native button)
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
                    
                    // Sign in with Google
                    Button {
                        authManager.signInWithGoogle()
                    } label: {
                        HStack(spacing: KHOITheme.spacing_md) {
                            Image(systemName: "globe") // swap for real Google icon asset if you add one
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
                
                // Terms text
                Text("By pressing on “Continue with…” you agree to our Privacy Policy and Terms and Conditions")
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
    @Published var posts: [InspoPost] = InspoPost.samples
    @Published var selectedCategory: ServiceCategory = .all
    
    // Saved state
    @Published var savedPostIDs: Set<UUID> = []
    @Published var saveCounts: [UUID: Int] = [:]
    
    // Posts shown in Discover
    var filteredPosts: [InspoPost] {
        if selectedCategory == .all {
            return posts
        }
        // later you can filter here by category
        return posts
    }
    
    // Posts in the user's Collection
    var savedPosts: [InspoPost] {
        posts.filter { savedPostIDs.contains($0.id) }
    }
    
    func selectCategory(_ category: ServiceCategory) {
        selectedCategory = category
    }
    
    // Toggle save + update count
    func toggleSave(for post: InspoPost) {
        if savedPostIDs.contains(post.id) {
            savedPostIDs.remove(post.id)
        } else {
            savedPostIDs.insert(post.id)
        }
        
        // Increment save count the first time, keep it at least 1 once saved
        let current = saveCounts[post.id, default: 0]
        saveCounts[post.id] = max(current + 1, 1)
    }
    
    func isSaved(_ post: InspoPost) -> Bool {
        savedPostIDs.contains(post.id)
    }
    
    func saveCount(for post: InspoPost) -> Int {
        saveCounts[post.id, default: 0]
    }
}


// MARK: - Home View
struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Filter chips
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
                    
                    // Masonry grid
                    MasonryGrid(
                        items: viewModel.filteredPosts,
                        columns: 2,
                        spacing: KHOITheme.spacing_md
                    ) { post, width in
                        InspoCard(
                            post: post,
                            width: width,
                            isSaved: viewModel.isSaved(post),
                            saveCount: viewModel.saveCount(for: post),
                            onSaveTap: {
                                viewModel.toggleSave(for: post)
                            }
                        )
                    }
                }
            }
        }
    }
}


// MARK: - Appointments
struct Appointments: View {
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background
                    .ignoresSafeArea()
                
                Text("Appointments")
                    .font(KHOITheme.title2)
                    .foregroundColor(KHOIColors.mutedText)
            }
            .navigationTitle("Appointments")
        }
    }
}

// MARK: - Chats View
struct ChatsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background
                    .ignoresSafeArea()
                
                Text("Chats")
                    .font(KHOITheme.title2)
                    .foregroundColor(KHOIColors.mutedText)
            }
            .navigationTitle("Messages")
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

                VStack(alignment: .leading, spacing: KHOITheme.spacing_md) {
                    // Header: username + bio
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

                    // Section title
                    Text("My Collection")
                        .font(KHOITheme.headline)
                        .foregroundColor(KHOIColors.darkText)
                        .padding(.horizontal, KHOITheme.spacing_lg)
                        .padding(.top, KHOITheme.spacing_lg)

                    // Saved posts masonry grid
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
                            InspoCard(
                                post: post,
                                width: width,
                                isSaved: viewModel.isSaved(post),
                                saveCount: viewModel.saveCount(for: post),
                                onSaveTap: {
                                    viewModel.toggleSave(for: post)
                                }
                            )
                        }
                    }

                    Spacer()
                }
            }
            .navigationTitle("Profile")
        }
        Button(action: {
            authManager.logOut()
        }) {
            Text("Log Out")
                .foregroundColor(.red)
                .font(KHOITheme.body)
                .padding()
                .frame(maxWidth: .infinity)
                .background(KHOIColors.cardBackground)
                .clipShape(
                    RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md)
                )
                .padding(.horizontal)
        }
    }
}


// MARK: - Root View (Tab Bar)
struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var homeViewModel = HomeViewModel()
    @State private var selectedTab = 0
                                
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(viewModel: homeViewModel)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
                                        
            Appointments()
                .tabItem { Label("Appointments", systemImage: "calendar") }
                .tag(1)
                                        
            ChatsView()
                 .tabItem { Label("Chats", systemImage: "message.fill") }
                 .tag(2)
                                        
            ProfileView(viewModel: homeViewModel)
                 .tabItem { Label("Profile", systemImage: "person.fill") }
                 .tag(3)
            }
            .tint(KHOIColors.accentBrown)
     }
}

#Preview {
    ContentView(authManager: AuthManager())
}
