//
//  AppointmentPrep.swift
//  You
//

import Foundation

/// A prepared list of questions for an upcoming GP appointment, built from the
/// patient's flagged results so nothing important goes unasked.
///
/// Business rules:
/// - Questions are generated fresh from the current results each time, never stored,
///   so they can't drift out of date with the record.
/// - Each question keeps the marker it came from, so the patient can point at the
///   result while asking.
struct AppointmentPrep: Hashable {
    /// The day of the appointment the patient is preparing for.
    let appointmentOn: Date

    /// The questions to ask, one per flagged marker.
    let questions: [GPQuestion]

    /// One question for the GP, tied to the flagged marker that prompted it.
    struct GPQuestion: Identifiable, Hashable {
        var id: UUID = UUID()

        /// The marker this question is about, e.g. "Ferritin".
        let markerName: String

        /// The question in the patient's words, ready to read out.
        let question: String
    }
}
