//
//  ArtistProfileView.swift
//  TheKhoiApp
//
//  Artist profile view matching the design
//

import SwiftUI
import FirebaseFirestore

// MARK: - Artist Service Model
struct ArtistService: Identifiable, Codable {
    let id: String
    var name: String
    var description: String
    var recommendation: String?  // "Recommended for bridal makeup"
    var price: Double
    var duration: Int  // minutes
    var imageURL: String?
}

// MARK: - Artist Profile View
struct ArtistProfileView: View {
    let artist: Artist
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: ProfileTab = .posts
    @State private var artistPosts: [Post] = []
    @State private var artistServices: [ArtistService] = []
    @State private var isLoading = true
    @State private var showClaimSheet = false
    @State private var isSaved = false
    
    enum ProfileTab {
        case posts
        case services
    }
    
    var body: some View {
        ZStack {
            KHOIColors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Cover Photo + Profile Card
                    headerSection
                    
                    // Bio
                    bioSection
                    
                    // Reviews preview
                    reviewsPreview
                    
                    // Book Appointment Button
                    bookButton
                    
                    // Tabs (Posts / Services)
                    tabsSection
                    
                    // Content based on tab
                    tabContent
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(artist.username)
                    .font(KHOITheme.headline)
                    .foregroundColor(KHOIColors.darkText)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: KHOITheme.spacing_md) {
                    Button {
                        isSaved.toggle()
                    } label: {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .foregroundColor(KHOIColors.darkText)
                    }
                    
                    Button {
                        // Share
                    } label: {
                        Image(systemName: "paperplane")
                            .foregroundColor(KHOIColors.darkText)
                    }
                    
                    Button {
                        // Message
                    } label: {
                        Image(systemName: "message")
                            .foregroundColor(KHOIColors.darkText)
                    }
                }
            }
        }
        .sheet(isPresented: $showClaimSheet) {
            ClaimProfileSheet(artist: artist)
        }
        .onAppear {
            fetchArtistData()
        }
    }
    
    // MARK: - Header Section (Cover + Profile Card)
    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            // Cover Image
            if let coverURL = artist.coverImageURL, let url = URL(string: coverURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(KHOIColors.chipBackground)
                }
                .frame(height: 140)
                .clipped()
            } else if let profileURL = artist.profileImageURL, let url = URL(string: profileURL) {
                // Use profile image as cover with blur
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 20)
                } placeholder: {
                    Rectangle().fill(KHOIColors.chipBackground)
                }
                .frame(height: 140)
                .clipped()
            } else {
                Rectangle()
                    .fill(KHOIColors.softBrown.opacity(0.3))
                    .frame(height: 140)
            }
            
            // Profile Card
            profileCard
                .offset(y: 60)
        }
        .padding(.bottom, 70)
    }
    
    // MARK: - Profile Card
    private var profileCard: some View {
        HStack(alignment: .top, spacing: KHOITheme.spacing_md) {
            // Profile Image
            profileImage
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(artist.fullName)
                    .font(KHOITheme.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(KHOIColors.darkText)
                
                // Referrals
                HStack(spacing: 4) {
                    Image(systemName: "paperplane.fill")
                        .font(.caption2)
                        .foregroundColor(.red.opacity(0.8))
                    Text("\(artist.referralCount) referrals")
                        .font(KHOITheme.caption)
                        .foregroundColor(KHOIColors.mutedText)
                }
                
                // Location
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption2)
                        .foregroundColor(KHOIColors.mutedText)
                    Text(artist.city)
                        .font(KHOITheme.caption)
                        .foregroundColor(KHOIColors.mutedText)
                }
                
                // Service Tags
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(artist.services.prefix(3), id: \.self) { service in
                            ServiceTagBadge(service: service)
                        }
                    }
                }
                .padding(.top, 4)
            }
            
            Spacer()
        }
        .padding()
        .background(KHOIColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_lg))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .padding(.horizontal)
    }
    
    // MARK: - Profile Image
    private var profileImage: some View {
        Group {
            if let imageURL = artist.profileImageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(KHOIColors.chipBackground)
                        .overlay(
                            Text(artist.fullName.prefix(1).uppercased())
                                .font(KHOITheme.title2)
                                .foregroundColor(KHOIColors.mutedText)
                        )
                }
            } else {
                Circle()
                    .fill(KHOIColors.chipBackground)
                    .overlay(
                        Text(artist.fullName.prefix(1).uppercased())
                            .font(KHOITheme.title2)
                            .foregroundColor(KHOIColors.mutedText)
                    )
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(KHOIColors.cardBackground, lineWidth: 3)
        )
    }
    
    // MARK: - Bio Section
    private var bioSection: some View {
        Group {
            if !artist.bio.isEmpty {
                Text(artist.bio)
                    .font(KHOITheme.body)
                    .foregroundColor(KHOIColors.darkText)
                    .padding(.horizontal)
                    .padding(.top, KHOITheme.spacing_sm)
            }
        }
    }
    
    // MARK: - Reviews Preview
    private var reviewsPreview: some View {
        Button {
            // Navigate to reviews
        } label: {
            HStack {
                // Reviewer avatars (overlapping)
                HStack(spacing: -8) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color(hex: ["E8B4B8", "A89080", "D4A574"][index]))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle().stroke(KHOIColors.cardBackground, lineWidth: 2)
                            )
                    }
                }
                
                Text("\(artist.reviewCount) client reviews")
                    .font(KHOITheme.callout)
                    .foregroundColor(KHOIColors.darkText)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(KHOIColors.mutedText)
            }
            .padding()
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Book Button
    private var bookButton: some View {
        Button {
            // Book appointment action
        } label: {
            Text("Book Appointment")
                .font(KHOITheme.headline)
                .foregroundColor(KHOIColors.darkText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, KHOITheme.spacing_md)
                .background(KHOIColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md))
                .overlay(
                    RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md)
                        .stroke(KHOIColors.divider, lineWidth: 1)
                )
        }
        .padding(.horizontal)
        .padding(.bottom, KHOITheme.spacing_md)
    }
    
    // MARK: - Tabs Section
    private var tabsSection: some View {
        HStack {
            // Posts Tab
            Button {
                selectedTab = .posts
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.title3)
                        .foregroundColor(selectedTab == .posts ? KHOIColors.darkText : KHOIColors.mutedText)
                    
                    Rectangle()
                        .fill(selectedTab == .posts ? KHOIColors.darkText : Color.clear)
                        .frame(height: 2)
                }
            }
            .frame(maxWidth: .infinity)
            
            // Services Tab (99 icon from design)
            Button {
                selectedTab = .services
            } label: {
                VStack(spacing: 8) {
                    Text("99")
                        .font(KHOITheme.headline)
                        .foregroundColor(selectedTab == .services ? KHOIColors.darkText : KHOIColors.mutedText)
                    
                    Rectangle()
                        .fill(selectedTab == .services ? KHOIColors.darkText : Color.clear)
                        .frame(height: 2)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Tab Content
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .posts:
            postsGrid
        case .services:
            servicesList
        }
    }
    
    // MARK: - Posts Grid
    private var postsGrid: some View {
        Group {
            if isLoading {
                ProgressView()
                    .padding()
            } else if artistPosts.isEmpty {
                VStack(spacing: KHOITheme.spacing_md) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.largeTitle)
                        .foregroundColor(KHOIColors.mutedText)
                    Text("No posts yet")
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.mutedText)
                }
                .padding(.vertical, KHOITheme.spacing_xxl)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2)
                ], spacing: 2) {
                    ForEach(artistPosts) { post in
                        PostGridItem(post: post)
                    }
                }
            }
        }
    }
    
    // MARK: - Services List
    private var servicesList: some View {
        LazyVStack(spacing: KHOITheme.spacing_md) {
            ForEach(artistServices) { service in
                ServiceCard(service: service)
            }
            
            // If no services, show placeholder
            if artistServices.isEmpty && !isLoading {
                VStack(spacing: KHOITheme.spacing_md) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.largeTitle)
                        .foregroundColor(KHOIColors.mutedText)
                    Text("No services listed yet")
                        .font(KHOITheme.body)
                        .foregroundColor(KHOIColors.mutedText)
                }
                .padding(.vertical, KHOITheme.spacing_xxl)
            }
        }
        .padding()
    }
    
    // MARK: - Data Fetching
    private func fetchArtistData() {
        let db = Firestore.firestore()
        
        // Fetch posts
        db.collection("posts")
            .whereField("artistId", isEqualTo: artist.id)
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    artistPosts = documents.compactMap { Post(document: $0) }
                }
            }
        
        // Fetch services
        db.collection("artists")
            .document(artist.id)
            .collection("services")
            .order(by: "price")
            .getDocuments { snapshot, error in
                isLoading = false
                if let documents = snapshot?.documents {
                    artistServices = documents.compactMap { doc -> ArtistService? in
                        let data = doc.data()
                        return ArtistService(
                            id: doc.documentID,
                            name: data["name"] as? String ?? "",
                            description: data["description"] as? String ?? "",
                            recommendation: data["recommendation"] as? String,
                            price: data["price"] as? Double ?? 0,
                            duration: data["duration"] as? Int ?? 60,
                            imageURL: data["imageURL"] as? String
                        )
                    }
                }
            }
    }
}

// MARK: - Service Tag Badge
struct ServiceTagBadge: View {
    let service: String
    
    var tagColor: Color {
        switch service.lowercased() {
        case "makeup": return Color(hex: "E8B4B8")
        case "hair": return Color(hex: "A89080")
        case "nails": return Color(hex: "D4A574")
        case "lashes": return Color(hex: "B8A9C9")
        case "skin": return Color(hex: "F5CBA7")
        case "brows": return Color(hex: "C9B99A")
        default: return KHOIColors.chipBackground
        }
    }
    
    var body: some View {
        Text(service.uppercased())
            .font(KHOITheme.caption2)
            .fontWeight(.semibold)
            .foregroundColor(KHOIColors.darkText)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(tagColor)
            .clipShape(Capsule())
    }
}

// MARK: - Post Grid Item
struct PostGridItem: View {
    let post: Post
    
    var body: some View {
        if let url = URL(string: post.imageURL), !post.imageURL.isEmpty {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(KHOIColors.chipBackground)
            }
            .aspectRatio(1, contentMode: .fill)
            .clipped()
        } else {
            Rectangle()
                .fill(KHOIColors.chipBackground)
                .aspectRatio(1, contentMode: .fill)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(KHOIColors.mutedText)
                )
        }
    }
}

// MARK: - Service Card
struct ServiceCard: View {
    let service: ArtistService
    
    var body: some View {
        HStack(spacing: KHOITheme.spacing_md) {
            // Service Image
            if let imageURL = service.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(KHOIColors.chipBackground)
                }
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_sm))
            } else {
                Rectangle()
                    .fill(KHOIColors.chipBackground)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_sm))
                    .overlay(
                        Image(systemName: "sparkles")
                            .foregroundColor(KHOIColors.mutedText)
                    )
            }
            
            // Service Info
            VStack(alignment: .leading, spacing: 4) {
                Text(service.name)
                    .font(KHOITheme.headline)
                    .foregroundColor(KHOIColors.darkText)
                
                Text(service.description)
                    .font(KHOITheme.caption)
                    .foregroundColor(KHOIColors.mutedText)
                    .lineLimit(2)
                
                if let recommendation = service.recommendation {
                    Text(recommendation)
                        .font(KHOITheme.caption)
                        .italic()
                        .foregroundColor(KHOIColors.accentBrown)
                }
                
                HStack {
                    Text("$\(Int(service.price))")
                        .font(KHOITheme.headline)
                        .foregroundColor(KHOIColors.darkText)
                    
                    Text("/ \(service.duration) min")
                        .font(KHOITheme.caption)
                        .foregroundColor(KHOIColors.mutedText)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(KHOIColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md))
    }
}

// MARK: - Claim Profile Sheet
struct ClaimProfileSheet: View {
    let artist: Artist
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var feedService = FeedService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var verificationNote = ""
    @State private var instagramHandle = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background.ignoresSafeArea()
                
                if showSuccess {
                    successView
                } else {
                    formView
                }
            }
            .navigationTitle("Claim Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private var formView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KHOITheme.spacing_lg) {
                // Artist Info
                HStack(spacing: KHOITheme.spacing_md) {
                    Circle()
                        .fill(KHOIColors.chipBackground)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Text(artist.fullName.prefix(1).uppercased())
                                .font(KHOITheme.title2)
                                .foregroundColor(KHOIColors.mutedText)
                        )
                    
                    VStack(alignment: .leading) {
                        Text(artist.fullName)
                            .font(KHOITheme.headline)
                            .foregroundColor(KHOIColors.darkText)
                        Text(artist.displayHandle)
                            .font(KHOITheme.callout)
                            .foregroundColor(KHOIColors.mutedText)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(KHOIColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md))
                
                Text("To verify you own this profile, please provide:")
                    .font(KHOITheme.body)
                    .foregroundColor(KHOIColors.darkText)
                
                // Instagram Handle
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your Instagram Handle")
                        .font(KHOITheme.callout)
                        .foregroundColor(KHOIColors.mutedText)
                    
                    TextField("@yourhandle", text: $instagramHandle)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(KHOIColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md))
                }
                
                // Verification Note
                VStack(alignment: .leading, spacing: 6) {
                    Text("How can we verify this is you?")
                        .font(KHOITheme.callout)
                        .foregroundColor(KHOIColors.mutedText)
                    
                    TextEditor(text: $verificationNote)
                        .frame(minHeight: 100)
                        .padding(10)
                        .background(KHOIColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md))
                    
                    Text("Example: DM us from your Instagram, or describe your business")
                        .font(KHOITheme.caption)
                        .foregroundColor(KHOIColors.mutedText)
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(KHOITheme.caption)
                        .foregroundColor(.red)
                }
                
                // Submit Button
                Button {
                    submitClaim()
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isSubmitting ? "Submitting..." : "Submit Claim Request")
                            .font(KHOITheme.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, KHOITheme.spacing_lg)
                    .background(canSubmit ? KHOIColors.accentBrown : KHOIColors.mutedText)
                    .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md))
                }
                .disabled(!canSubmit || isSubmitting)
            }
            .padding()
        }
    }
    
    private var successView: some View {
        VStack(spacing: KHOITheme.spacing_xl) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Request Submitted!")
                .font(KHOITheme.title2)
                .foregroundColor(KHOIColors.darkText)
            
            Text("We'll review your claim and get back to you within 24-48 hours.")
                .font(KHOITheme.body)
                .foregroundColor(KHOIColors.mutedText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(KHOITheme.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, KHOITheme.spacing_lg)
                    .background(KHOIColors.accentBrown)
                    .clipShape(RoundedRectangle(cornerRadius: KHOITheme.cornerRadius_md))
            }
            .padding(.horizontal)
        }
    }
    
    private var canSubmit: Bool {
        !verificationNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func submitClaim() {
        guard let userId = authManager.firebaseUID,
              let user = authManager.currentUser else {
            errorMessage = "Please sign in to claim this profile"
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        
        feedService.submitClaimRequest(
            artistId: artist.id,
            userId: userId,
            userEmail: user.email,
            userName: user.fullName,
            verificationNote: verificationNote.trimmingCharacters(in: .whitespacesAndNewlines),
            instagramHandle: instagramHandle.isEmpty ? nil : instagramHandle
        ) { result in
            isSubmitting = false
            
            switch result {
            case .success:
                showSuccess = true
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}
