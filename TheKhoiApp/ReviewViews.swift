//
//  ReviewViews.swift
//  TheKhoiApp
//
//  UI components for the review system
//

import SwiftUI
import PhotosUI

// MARK: - Reviews List View (for Reviews Tab)

struct ReviewsListView: View {
    let artist: Artist
    @Binding var showReviewLimitPopup: Bool  // Binding to parent for full-screen overlay
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var reviewService = ReviewService()
    
    @State private var showWriteReview = false
    @State private var canReview = false
    @State private var userAppointments: [Appointment] = []
    @State private var isCheckingEligibility = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with review count and write button
            reviewHeader
            
            // Reviews list
            if reviewService.isLoading {
                ProgressView()
                    .tint(KHOIColors.accentBrown)
                    .padding(.top, 40)
            } else if reviewService.reviews.isEmpty {
                emptyReviewsState
            } else {
                reviewsList
            }
        }
        .onAppear {
            reviewService.fetchReviews(forArtistId: artist.id)
        }
        .sheet(isPresented: $showWriteReview) {
            WriteReviewView(
                artist: artist,
                userAppointments: userAppointments,
                onSubmit: { showWriteReview = false }
            )
            .environmentObject(authManager)
        }
    }
    
    // MARK: - Header
    
    private var reviewHeader: some View {
        HStack {
            // Rating and count
            HStack(spacing: 8) {
                if reviewService.reviewStats.totalReviews > 0 {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= Int(reviewService.reviewStats.averageRating.rounded()) ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "D4A574"))
                        }
                    }
                }
                
                Text("\(reviewService.reviewStats.totalReviews) client reviews")
                    .font(.system(size: 13))
                    .foregroundColor(KHOIColors.mutedText)
            }
            
            Spacer()
            
            // Write review button
            if authManager.firebaseUID != artist.id {
                Button(action: checkReviewEligibility) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                        .foregroundColor(KHOIColors.darkText)
                        .padding(8)
                        .background(KHOIColors.chipBackground)
                        .clipShape(Circle())
                }
                .disabled(isCheckingEligibility)
                .overlay {
                    if isCheckingEligibility {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                }
            }
        }
        .padding(.horizontal, KHOITheme.spacing_md)
        .padding(.vertical, 12)
    }
    
    // MARK: - Empty State
    
    private var emptyReviewsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.bubble")
                .font(.system(size: 48))
                .foregroundColor(KHOIColors.mutedText.opacity(0.4))
            
            Text("No reviews yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(KHOIColors.darkText)
            
            Text("Be the first to leave a review!")
                .font(.system(size: 13))
                .foregroundColor(KHOIColors.mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Reviews List
    
    private var reviewsList: some View {
        LazyVStack(spacing: 16) {
            ForEach(reviewService.reviews) { review in
                ReviewCard(review: review)
            }
        }
        .padding(.horizontal, KHOITheme.spacing_md)
        .padding(.bottom, 100)
    }
    
    // MARK: - Check Eligibility
    
    private func checkReviewEligibility() {
        guard let userId = authManager.firebaseUID else { return }
        
        isCheckingEligibility = true
        
        // First check if user has already reviewed
        reviewService.hasUserReviewed(userId: userId, artistId: artist.id) { hasReviewed in
            if hasReviewed {
                // User already reviewed - could show a message
                isCheckingEligibility = false
                return
            }
            
            // Check if user has had an appointment
            reviewService.checkCanReview(userId: userId, artistId: artist.id) { canReview, appointments in
                DispatchQueue.main.async {
                    isCheckingEligibility = false
                    
                    if canReview {
                        self.userAppointments = appointments
                        self.showWriteReview = true
                    } else {
                        self.showReviewLimitPopup = true
                    }
                }
            }
        }
    }
}

// MARK: - Review Card

struct ReviewCard: View {
    let review: Review
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Review text
            Text(review.reviewText)
                .font(.system(size: 14))
                .foregroundColor(KHOIColors.darkText)
                .lineSpacing(4)
            
            // Timestamp
            Text(review.timeAgo)
                .font(.system(size: 11))
                .foregroundColor(KHOIColors.mutedText)
            
            // Review images
            if !review.images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(review.images, id: \.self) { imageURL in
                            AsyncImage(url: URL(string: imageURL)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Author info
            HStack(spacing: 10) {
                // Profile image
                if review.isAnonymous {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 16))
                                .foregroundColor(KHOIColors.mutedText)
                        )
                } else {
                    AsyncImage(url: URL(string: review.authorProfileImageURL ?? "")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                }
                
                // Name and service
                VStack(alignment: .leading, spacing: 2) {
                    Text(review.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(review.isAnonymous ? KHOIColors.mutedText : KHOIColors.darkText)
                        .italic(review.isAnonymous)
                    
                    if !review.isAnonymous {
                        Text(review.displayUsername)
                            .font(.system(size: 11))
                            .foregroundColor(KHOIColors.mutedText)
                    }
                }
                
                Spacer()
                
                // Service badge and rating
                VStack(alignment: .trailing, spacing: 4) {
                    Text(review.serviceReceived)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(KHOIColors.darkText)
                    
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= review.rating ? "star.fill" : "star")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "D4A574"))
                        }
                    }
                }
            }
        }
        .padding()
        .background(KHOIColors.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Review Limit Popup

struct ReviewLimitPopup: View {
    @Binding var isPresented: Bool
    let onBookAppointment: () -> Void
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // Popup content
            VStack(spacing: 20) {
                // Heart icon
                Image("heart")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .padding(.top, 32)
                
                // Message
                VStack(spacing: 8) {
                    Text("ouchie! looks like you haven't")
                        .font(.system(size: 15))
                        .foregroundColor(KHOIColors.darkText)
                    Text("been to this artist yet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(KHOIColors.darkText)
                }
                
                Text("book now to leave a review!")
                    .font(.system(size: 13))
                    .foregroundColor(KHOIColors.mutedText)
                
                // Buttons
                HStack(spacing: 16) {
                    Button("Not now") {
                        isPresented = false
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(KHOIColors.mutedText)
                    
                    Button(action: onBookAppointment) {
                        Text("Book Appointment")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(KHOIColors.darkText)
                            .cornerRadius(20)
                    }
                }
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 300)
            .background(KHOIColors.cardBackground)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.15), radius: 20)
        }
    }
}

// MARK: - Write Review View

struct WriteReviewView: View {
    let artist: Artist
    let userAppointments: [Appointment]
    let onSubmit: () -> Void
    
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var reviewService = ReviewService()
    @StateObject private var formState = ReviewFormState()
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Get unique services from appointments
    private var availableServices: [String] {
        Array(Set(userAppointments.map { $0.serviceName }))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                KHOIColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Rating section
                        ratingSection
                        
                        // Review text section
                        reviewTextSection
                        
                        // Anonymous toggle
                        anonymousSection
                        
                        // Service selection
                        serviceSection
                        
                        // Upload pics
                        uploadPicsSection
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
                
                // Submit button
                VStack {
                    Spacer()
                    submitButton
                }
            }
            .navigationTitle(artist.displayHandle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(KHOIColors.darkText)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Rating Section
    
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RATING")
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundColor(KHOIColors.darkText)
            
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Button(action: { formState.rating = star }) {
                        Image(systemName: star <= formState.rating ? "star.fill" : "star")
                            .font(.system(size: 32))
                            .foregroundColor(star <= formState.rating ? Color(hex: "D4A574") : Color.gray.opacity(0.3))
                    }
                }
            }
        }
    }
    
    // MARK: - Review Text Section
    
    private var reviewTextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("REVIEW")
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundColor(KHOIColors.darkText)
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $formState.reviewText)
                    .frame(minHeight: 120)
                    .padding(12)
                    .background(KHOIColors.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                
                if formState.reviewText.isEmpty {
                    Text("Tell us your experience...")
                        .font(.system(size: 14))
                        .foregroundColor(KHOIColors.mutedText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
            
            HStack {
                Spacer()
                Text("\(formState.characterCount) / \(formState.maxCharacters) characters")
                    .font(.system(size: 11))
                    .foregroundColor(KHOIColors.mutedText)
            }
        }
        .onChange(of: formState.reviewText) { newValue in
            if newValue.count > formState.maxCharacters {
                formState.reviewText = String(newValue.prefix(formState.maxCharacters))
            }
        }
    }
    
    // MARK: - Anonymous Section
    
    private var anonymousSection: some View {
        Button(action: { formState.isAnonymous.toggle() }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: formState.isAnonymous ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(formState.isAnonymous ? KHOIColors.accentBrown : KHOIColors.mutedText)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Yes, please keep my review anonymous.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(KHOIColors.darkText)
                    
                    Text("By selecting this option, we will remove your personal information from your review including profile picture, name, and username.")
                        .font(.system(size: 12))
                        .foregroundColor(KHOIColors.mutedText)
                        .lineSpacing(2)
                }
            }
        }
    }
    
    // MARK: - Service Section
    
    private var serviceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SERVICE")
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundColor(KHOIColors.darkText)
            
            VStack(spacing: 0) {
                ForEach(availableServices, id: \.self) { service in
                    Button(action: { formState.selectedService = service }) {
                        HStack {
                            Text(service)
                                .font(.system(size: 14))
                                .foregroundColor(KHOIColors.darkText)
                            
                            Spacer()
                            
                            Circle()
                                .stroke(formState.selectedService == service ? KHOIColors.accentBrown : Color.gray.opacity(0.3), lineWidth: 2)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .fill(formState.selectedService == service ? KHOIColors.accentBrown : Color.clear)
                                        .frame(width: 12, height: 12)
                                )
                        }
                        .padding(.vertical, 14)
                    }
                    
                    if service != availableServices.last {
                        Divider()
                    }
                }
            }
        }
    }
    
    // MARK: - Upload Pics Section
    
    private var uploadPicsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UPLOAD PICS")
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundColor(KHOIColors.darkText)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    if index < formState.selectedImages.count {
                        // Show uploaded image
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: formState.selectedImages[index])
                                .resizable()
                                .scaledToFill()
                                .frame(height: 80)
                                .clipped()
                                .cornerRadius(8)
                            
                            Button(action: {
                                formState.selectedImages.remove(at: index)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                            }
                            .padding(4)
                        }
                    } else {
                        // Upload placeholder
                        PhotosPicker(
                            selection: $selectedPhotos,
                            maxSelectionCount: 6 - formState.selectedImages.count,
                            matching: .images
                        ) {
                            VStack(spacing: 4) {
                                Image(systemName: "photo")
                                    .font(.system(size: 20))
                                    .foregroundColor(KHOIColors.mutedText)
                                
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(KHOIColors.mutedText)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                    .foregroundColor(Color.gray.opacity(0.3))
                            )
                        }
                    }
                }
            }
        }
        .onChange(of: selectedPhotos) { newItems in
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            if formState.selectedImages.count < 6 {
                                formState.selectedImages.append(image)
                            }
                        }
                    }
                }
                await MainActor.run {
                    selectedPhotos = []
                }
            }
        }
    }
    
    // MARK: - Submit Button
    
    private var submitButton: some View {
        Button(action: submitReview) {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Submit review")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(formState.isValid ? KHOIColors.darkText : Color.gray.opacity(0.4))
            .cornerRadius(12)
        }
        .disabled(!formState.isValid || isSubmitting)
        .padding(.horizontal)
        .padding(.bottom, 24)
        .background(
            LinearGradient(
                colors: [KHOIColors.background.opacity(0), KHOIColors.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)
            .allowsHitTesting(false)
        )
    }
    
    // MARK: - Submit Review
    
    private func submitReview() {
        guard let currentUser = authManager.currentUser,
              let userId = authManager.firebaseUID else { return }
        
        isSubmitting = true
        
        // Create review
        let review = Review(
            rating: formState.rating,
            reviewText: formState.reviewText,
            serviceReceived: formState.selectedService,
            images: [],
            authorId: userId,
            authorName: currentUser.fullName,
            authorUsername: currentUser.username,
            authorProfileImageURL: currentUser.profileImageURL,
            isAnonymous: formState.isAnonymous,
            artistId: artist.id,
            artistName: artist.fullName
        )
        
        // If there are images, upload them first
        if !formState.selectedImages.isEmpty {
            let tempReviewId = UUID().uuidString
            reviewService.uploadReviewImages(images: formState.selectedImages, reviewId: tempReviewId) { result in
                switch result {
                case .success(let urls):
                    var reviewWithImages = review
                    reviewWithImages.images = urls
                    submitReviewToFirebase(reviewWithImages)
                case .failure(let error):
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        } else {
            submitReviewToFirebase(review)
        }
    }
    
    private func submitReviewToFirebase(_ review: Review) {
        reviewService.submitReview(review) { result in
            isSubmitting = false
            
            switch result {
            case .success:
                onSubmit()
                dismiss()
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
