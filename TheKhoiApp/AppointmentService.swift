//
//  AppointmentService.swift
//  TheKhoiApp
//
//  Created by Anjo on 12/2/25.
//


import Foundation
import FirebaseFirestore
import Combine

class AppointmentService: ObservableObject {
    @Published var appointments: [Appointment] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    /// Listen for real-time updates to the user's appointments
    func listenToAppointments(userId: String) {
        isLoading = true
        listener?.remove()
        
        // Note: This query requires a Firestore Index.
        // If the app crashes or logs an index error, click the link in the debug console to create it.
        listener = db.collection("appointments")
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: false) // Closest dates first
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error loading appointments: \(error.localizedDescription)"
                    print("❌ Error listening to appointments: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self.appointments = documents.compactMap { Appointment(document: $0) }
            }
    }
    
    /// Create a new appointment
    func bookAppointment(appointment: Appointment, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try db.collection("appointments").document(appointment.id).setData(appointment.toFirestoreData())
            print("✅ Appointment booked successfully")
            completion(.success(()))
        } catch {
            print("❌ Error booking appointment: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
    
    /// Cancel an appointment
    func cancelAppointment(appointmentId: String) {
        db.collection("appointments").document(appointmentId).updateData([
            "status": AppointmentStatus.cancelled.rawValue
        ]) { error in
            if let error = error {
                print("❌ Error cancelling appointment: \(error.localizedDescription)")
            } else {
                print("✅ Appointment cancelled")
            }
        }
    }
    
    func stopListening() {
        listener?.remove()
    }
    
    deinit {
        stopListening()
    }
}
