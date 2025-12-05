//
//  BookingService.swift
//  TheKhoiApp
//
//  Created by Anjo on 12/4/25.
//

import Foundation
import FirebaseFirestore

class BookingService: ObservableObject {
    @Published var appointments: [Appointment] = []
    @Published var isLoading = false
    private let db = Firestore.firestore()
    
    // MARK: - Create Booking
    func createBooking(appointment: Appointment, completion: @escaping (Bool) -> Void) {
        do {
            let _ = try db.collection("appointments").addDocument(from: appointment)
            completion(true)
        } catch {
            print("Error saving appointment: \(error)")
            completion(false)
        }
    }
    
    // MARK: - Fetch Bookings
    func fetchAppointments(userID: String, isBusiness: Bool) {
        isLoading = true
        
        // If business, look for artistID. If client, look for clientID.
        let fieldToCheck = isBusiness ? "artistID" : "clientID"
        
        db.collection("appointments")
            .whereField(fieldToCheck, isEqualTo: userID)
            .order(by: "date", descending: false)
            .addSnapshotListener { snapshot, error in
                self.isLoading = false
                guard let documents = snapshot?.documents else {
                    print("No appointments found or error: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                
                self.appointments = documents.compactMap { doc -> Appointment? in
                    try? doc.data(as: Appointment.self)
                }
            }
    }
    
    // MARK: - Update Status (Accept/Decline/Cancel)
    func updateStatus(bookingID: String, status: AppointmentStatus) {
        db.collection("appointments").document(bookingID).updateData([
            "status": status.rawValue
        ])
    }
}
