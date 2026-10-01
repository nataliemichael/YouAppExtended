//
//  MarkerReading.swift
//  You
//

import Foundation

/// One measured marker inside a pathology report e.g a single line such as "Ferritin 9 µg/L (30–300)"
///
/// Business rules:
/// - A reading always keeps the unit the lab reported. Values are never compared across different units.
/// - `plainLanguageExplanation` teaches what the marker does in everyday words. It never gives medical advice, only the patient's GP does that.
struct MarkerReading: Identifiable, Codable, Hashable {
    var id: UUID = UUID()

    /// The lab's name for what was measured, e.g. "Ferritin"
    let markerName: String

    /// The measured value exactly as printed on the report
    let value: Double

    /// The unit exactly as printed on the report
    let unit: String

    /// The healthy interval the lab printed beside this marker
    let referenceRange: ReferenceRange

    /// What this marker means for the patient, in everyday words
    let plainLanguageExplanation: String

    /// Where this reading sits against the lab's healthy range
    var status: ReferenceRange.Status {
        referenceRange.status(for: value)
    }

    /// True when the value falls outside the healthy range and deserves the patient's attention at their next appointment.
    var isFlagged: Bool {
        status != .inRange
    }
}
