//
//  BookingService.swift
//  TheKhoiApp
//
//  Service for managing bookings and appointments in Firebase
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit

class BookingService: ObservableObject {
    @Published var appointments: [Appointment] = []
    @Published var clientAppointments: [Appointment] = []
    @Published var artistAppointments: [Appointment] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var appointmentsListener: ListenerRegistration?
    
    // MARK: - Create Appointment
    
    func createAppointment(_ appointment: Appointment, completion: @escaping (Result<String, Error>) -> Void) {
        isLoading = true
        
        let docRef = db.collection("appointments").document()
        var appointmentData = appointment
        appointmentData.id = docRef.documentID
        
        docRef.setData(appointmentData.toFirestoreData()) { [weak self] error in
            self?.isLoading = false
            
            if let error = error {
                self?.errorMessage = error.localizedDescription
                completion(.failure(error))
            } else {
                completion(.success(docRef.documentID))
            }
        }
    }
    
    // MARK: - Fetch Appointments for Artist (Pro View)
    
    func fetchArtistAppointments(artistId: String) {
        isLoading = true
        
        appointmentsListener?.remove()
        
        appointmentsListener = db.collection("appointments")
            .whereField("artistId", isEqualTo: artistId)
            .order(by: "date", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self?.artistAppointments = []
                    return
                }
                
                self?.artistAppointments = documents.compactMap { Appointment.fromFirestore(document: $0) }
            }
    }
    
    // MARK: - Fetch Appointments for Client
    
    func fetchClientAppointments(clientId: String) {
        isLoading = true
        
        db.collection("appointments")
            .whereField("clientId", isEqualTo: clientId)
            .order(by: "date", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self?.clientAppointments = []
                    return
                }
                
                self?.clientAppointments = documents.compactMap { Appointment.fromFirestore(document: $0) }
            }
    }
    
    // MARK: - Check Availability
    
    /// Check if artist has any appointments on a specific date and time
    func checkAvailability(
        artistId: String,
        date: Date,
        timeSlot: String,
        duration: Int,
        completion: @escaping (Bool) -> Void
    ) {
        // Get start of day for the selected date
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        db.collection("appointments")
            .whereField("artistId", isEqualTo: artistId)
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("date", isLessThan: Timestamp(date: endOfDay))
            .whereField("status", in: ["pending", "confirmed"])
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error checking availability: \(error)")
                    completion(false)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(true) // No appointments = available
                    return
                }
                
                // Check if any existing appointment overlaps with the requested time
                let existingAppointments = documents.compactMap { Appointment.fromFirestore(document: $0) }
                
                for appointment in existingAppointments {
                    if appointment.timeSlot == timeSlot {
                        completion(false) // Same time slot = not available
                        return
                    }
                    
                    // TODO: Add more sophisticated overlap checking based on duration
                }
                
                completion(true) // No conflicts found
            }
    }
    
    /// Get all booked time slots for an artist on a specific date
    func getBookedSlots(
        artistId: String,
        date: Date,
        completion: @escaping ([String]) -> Void
    ) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        db.collection("appointments")
            .whereField("artistId", isEqualTo: artistId)
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("date", isLessThan: Timestamp(date: endOfDay))
            .whereField("status", in: ["pending", "confirmed"])
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching booked slots: \(error)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                let bookedSlots = documents.compactMap { doc -> String? in
                    let data = doc.data()
                    return data["timeSlot"] as? String
                }
                
                completion(bookedSlots)
            }
    }
    
    // MARK: - Update Appointment Status
    
    func updateAppointmentStatus(
        appointmentId: String,
        status: AppointmentStatus,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var updateData: [String: Any] = [
            "status": status.rawValue,
            "updatedAt": Timestamp(date: Date())
        ]
        
        switch status {
        case .confirmed:
            updateData["confirmedAt"] = Timestamp(date: Date())
        case .cancelled:
            updateData["cancelledAt"] = Timestamp(date: Date())
        default:
            break
        }
        
        db.collection("appointments").document(appointmentId).updateData(updateData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Cancel Appointment
    
    func cancelAppointment(
        appointmentId: String,
        reason: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let updateData: [String: Any] = [
            "status": AppointmentStatus.cancelled.rawValue,
            "cancelledAt": Timestamp(date: Date()),
            "cancelReason": reason,
            "updatedAt": Timestamp(date: Date())
        ]
        
        db.collection("appointments").document(appointmentId).updateData(updateData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Upload Inspo Image
    
    func uploadInspoImage(
        image: UIImage,
        appointmentId: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let imageData = image.jpegData(compressionQuality: 0.6) else {
            completion(.failure(NSError(domain: "ImageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])))
            return
        }
        
        let imageId = UUID().uuidString
        let path = "inspo_images/\(appointmentId)/\(imageId).jpg"
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
    
    // MARK: - Get Upcoming Appointments Count
    
    func getUpcomingAppointmentsCount(artistId: String, completion: @escaping (Int) -> Void) {
        let now = Date()
        
        db.collection("appointments")
            .whereField("artistId", isEqualTo: artistId)
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: now))
            .whereField("status", in: ["pending", "confirmed"])
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error getting upcoming count: \(error)")
                    completion(0)
                    return
                }
                
                completion(snapshot?.documents.count ?? 0)
            }
    }
    
    // MARK: - Get Today's Appointments
    
    func getTodaysAppointments(artistId: String, completion: @escaping ([Appointment]) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        db.collection("appointments")
            .whereField("artistId", isEqualTo: artistId)
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("date", isLessThan: Timestamp(date: endOfDay))
            .whereField("status", in: ["pending", "confirmed"])
            .order(by: "date")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error getting today's appointments: \(error)")
                    completion([])
                    return
                }
                
                let appointments = snapshot?.documents.compactMap { Appointment.fromFirestore(document: $0) } ?? []
                completion(appointments)
            }
    }
    
    // MARK: - Cleanup
    
    func removeListener() {
        appointmentsListener?.remove()
    }
    
    deinit {
        removeListener()
    }
}
