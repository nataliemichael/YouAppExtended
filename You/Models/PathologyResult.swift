//
//  PathologyResult.swift
//  You
//

import Foundation

/// One pathology report: the document a patient receives after a blood test, holding every marker the lab measured from a single sample.
///
/// Business rules:
/// - A report belongs to one collection date. The same marker cannot appear twice for the same date (enforced by `RecordPathologyResultUseCase`).
/// - Reports are historical records. Once saved they are corrected by entering a new report, never silently edited, so the patient's history stays trustworthy.
struct PathologyResult: Identifiable, Codable, Hashable {
    var id: UUID = UUID()

    /// The day the blood sample was collected, how patients remember a report, as in "my June bloods".
    let collectedOn: Date

    /// The clinician who ordered the test, as shown on the report, e.g. "Dr Michael".
    let orderingClinician: String

    /// Every marker the lab measured in this report.
    let markers: [MarkerReading]

    /// The readings outside their healthy range: the ones worth discussing at the patient's next appointment.
    var flaggedMarkers: [MarkerReading] {
        markers.filter(\.isFlagged)
    }
}
