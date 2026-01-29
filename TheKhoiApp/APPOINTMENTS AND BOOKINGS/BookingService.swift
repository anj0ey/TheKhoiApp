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
                // Schedule appointment reminders for the client
                NotificationService.shared.scheduleAppointmentReminders(for: appointmentData)
                
                // Notify the pro about new booking request
                NotificationService.shared.sendNewBookingRequestNotification(appointment: appointmentData)
                
                completion(.success(docRef.documentID))
            }
        }
    }
    
    // MARK: - Fetch Appointments for Artist (Pro View)
    
    func fetchArtistAppointments(artistId: String) {
        isLoading = true
        
        appointmentsListener?.remove()
        
        print("DEBUG: Fetching appointments for artistId: \(artistId)")
        
        // Simple query - just filter by artistId, sort locally
        appointmentsListener = db.collection("appointments")
            .whereField("artistId", isEqualTo: artistId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("DEBUG ERROR: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("DEBUG: No documents returned")
                    self?.artistAppointments = []
                    return
                }
                
                print("DEBUG: Found \(documents.count) documents")
                
                let appointments = documents.compactMap { Appointment.fromFirestore(document: $0) }
                
                // Sort locally by date
                self?.artistAppointments = appointments.sorted { $0.date < $1.date }
                
                print("DEBUG: Loaded \(self?.artistAppointments.count ?? 0) appointments")
            }
    }
    
    // MARK: - Fetch Appointments for Client
    
    func fetchClientAppointments(clientId: String) {
        isLoading = true
        
        print("DEBUG: Fetching client appointments for clientId: \(clientId)")
        
        db.collection("appointments")
            .whereField("clientId", isEqualTo: clientId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("DEBUG ERROR: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("DEBUG: No documents returned for client")
                    self?.clientAppointments = []
                    return
                }
                
                print("DEBUG: Found \(documents.count) client documents")
                
                let appointments = documents.compactMap { Appointment.fromFirestore(document: $0) }
                self?.clientAppointments = appointments.sorted { $0.date < $1.date }
            }
    }
    
    // MARK: - Check Availability
    
    func checkAvailability(
        artistId: String,
        date: Date,
        timeSlot: String,
        duration: Int,
        completion: @escaping (Bool) -> Void
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
                    print("Error checking availability: \(error)")
                    completion(false)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(true)
                    return
                }
                
                let existingAppointments = documents.compactMap { Appointment.fromFirestore(document: $0) }
                
                for appointment in existingAppointments {
                    if appointment.timeSlot == timeSlot {
                        completion(false)
                        return
                    }
                }
                
                completion(true)
            }
    }
    
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
    
    // MARK: - Updated getBookedSlots with Duration (No Index Required)
    func getBookedSlotsWithDuration(
        artistId: String,
        date: Date,
        completion: @escaping ([BookedSlotInfo]) -> Void
    ) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        print("DEBUG BookingService: Searching for appointments")
        print("DEBUG BookingService: Artist ID: \(artistId)")
        print("DEBUG BookingService: Input date: \(date)")
        print("DEBUG BookingService: Start of day: \(startOfDay)")
        print("DEBUG BookingService: End of day: \(endOfDay)")
        print("DEBUG BookingService: Timestamp range: \(Timestamp(date: startOfDay)) to \(Timestamp(date: endOfDay))")
        
        // Simplified query - only filter by artistId and date
        // Filter status in-memory to avoid needing a composite index
        db.collection("appointments")
            .whereField("artistId", isEqualTo: artistId)
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("date", isLessThan: Timestamp(date: endOfDay))
            .getDocuments { snapshot, error in
                if let error = error {
                    print("DEBUG BookingService: Error - \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("DEBUG BookingService: No documents found (snapshot is nil)")
                    completion([])
                    return
                }
                
                print("DEBUG BookingService: Found \(documents.count) total documents before filtering")
                
                // 🔍 Debug: Print all found documents
                for doc in documents {
                    let data = doc.data()
                    print("DEBUG BookingService: Document \(doc.documentID)")
                    print("  - artistId: \(data["artistId"] ?? "nil")")
                    if let dateTimestamp = data["date"] as? Timestamp {
                        print("  - date (Timestamp): \(dateTimestamp.dateValue())")
                    } else {
                        print("  - date (raw): \(data["date"] ?? "nil")")
                    }
                    print("  - timeSlot: \(data["timeSlot"] ?? "nil")")
                    print("  - status: \(data["status"] ?? "nil")")
                    print("  - serviceDuration: \(data["serviceDuration"] ?? "nil")")
                }
                
                // Filter for pending/confirmed status in-memory
                let bookedSlots: [BookedSlotInfo] = documents.compactMap { doc -> BookedSlotInfo? in
                    let data = doc.data()
                    
                    // Filter by status in-memory
                    guard let statusStr = data["status"] as? String,
                          (statusStr == "pending" || statusStr == "confirmed") else {
                        print("DEBUG BookingService: Skipping \(doc.documentID) - status is \(data["status"] ?? "nil")")
                        return nil
                    }
                    
                    guard let timeSlot = data["timeSlot"] as? String,
                          let duration = data["serviceDuration"] as? Int else {
                        print("DEBUG BookingService: Missing timeSlot or duration in document \(doc.documentID)")
                        print("  - timeSlot: \(data["timeSlot"] ?? "nil")")
                        print("  - serviceDuration: \(data["serviceDuration"] ?? "nil")")
                        return nil
                    }
                    
                    // Parse time slot to get minutes
                    let formatter = DateFormatter()
                    formatter.dateFormat = "h:mm a"
                    guard let time = formatter.date(from: timeSlot) else {
                        print("DEBUG BookingService: Failed to parse timeSlot: \(timeSlot)")
                        return nil
                    }
                    
                    let hour = calendar.component(.hour, from: time)
                    let minute = calendar.component(.minute, from: time)
                    let startMinutes = hour * 60 + minute
                    let endMinutes = startMinutes + duration
                    
                    print("DEBUG BookingService: ✅ Booked slot - \(timeSlot), duration: \(duration)min, range: \(startMinutes)-\(endMinutes)")
                    
                    return BookedSlotInfo(
                        timeSlot: timeSlot,
                        duration: duration,
                        startMinutes: startMinutes,
                        endMinutes: endMinutes
                    )
                }
                
                print("DEBUG BookingService: Returning \(bookedSlots.count) booked slots after filtering")
                completion(bookedSlots)
            }
    }
    
    // MARK: - Test Query (Debug Helper)
    func testQueryAllAppointments(artistId: String) {
        print("🔍 TEST: Querying ALL appointments for artist: \(artistId)")
        
        db.collection("appointments")
            .whereField("artistId", isEqualTo: artistId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("🔍 TEST ERROR: \(error.localizedDescription)")
                    return
                }
                
                let count = snapshot?.documents.count ?? 0
                print("🔍 TEST: Found \(count) total appointments (no date filter)")
                
                for doc in snapshot?.documents ?? [] {
                    let data = doc.data()
                    print("🔍 TEST Appointment \(doc.documentID):")
                    print("  - artistId: \(data["artistId"] ?? "nil")")
                    
                    if let dateTimestamp = data["date"] as? Timestamp {
                        print("  - date: \(dateTimestamp.dateValue())")
                        print("  - date type: Timestamp")
                    } else {
                        print("  - date: \(data["date"] ?? "nil")")
                        print("  - date type: \(type(of: data["date"]))")
                    }
                    
                    print("  - timeSlot: \(data["timeSlot"] ?? "nil")")
                    print("  - status: \(data["status"] ?? "nil")")
                    print("  - serviceDuration: \(data["serviceDuration"] ?? "nil")")
                    print("  ---")
                }
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
        
        db.collection("appointments").document(appointmentId).updateData(updateData) { [weak self] error in
            if let error = error {
                completion(.failure(error))
            } else {
                self?.db.collection("appointments").document(appointmentId).getDocument { snapshot, _ in
                    if let appointment = snapshot.flatMap({ Appointment.fromFirestore(document: $0) }) {
                        switch status {
                        case .confirmed:
                            NotificationService.shared.sendBookingConfirmedNotification(appointment: appointment)
                        case .cancelled:
                            NotificationService.shared.sendBookingCancelledNotification(appointment: appointment, reason: nil)
                        default:
                            break
                        }
                    }
                }
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
        
        db.collection("appointments").document(appointmentId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            let appointment = snapshot.flatMap { Appointment.fromFirestore(document: $0) }
            
            self.db.collection("appointments").document(appointmentId).updateData(updateData) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    if let appointment = appointment {
                        NotificationService.shared.sendBookingCancelledNotification(
                            appointment: appointment,
                            reason: reason
                        )
                        NotificationService.shared.cancelAppointmentReminders(appointmentId: appointmentId)
                    }
                    completion(.success(()))
                }
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
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error getting today's appointments: \(error)")
                    completion([])
                    return
                }
                
                let appointments = snapshot?.documents.compactMap { Appointment.fromFirestore(document: $0) } ?? []
                completion(appointments.sorted { $0.date < $1.date })
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
