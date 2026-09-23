//
//  RecordPathologyResultUseCase.swift
//  You
//

import Foundation

/// The reasons recording a result can fail, each written for the patient with a way forward.
enum RecordPathologyResultError: LocalizedError, Equatable {
    /// The typed healthy range is impossible, e.g. the low end is above the high end.
    case referenceRangeInvalid
    /// The collection date is after today, which no real report can have.
    case collectionDateInFuture
    /// The value is outside anything a lab could plausibly report, a likely typo.
    case valueNotPhysiologicallyPlausible(markerName: String)
    /// This marker is already saved for this date.
    case duplicateMarkerForDate(markerName: String)

    var errorDescription: String? {
        switch self {
        case .referenceRangeInvalid:
            return "The healthy range doesn't look right, the low number should be smaller than the high number. Copy both numbers from the brackets on your report."
        case .collectionDateInFuture:
            return "The collection date can't be in the future. Check the date printed on your report and try again."
        case .valueNotPhysiologicallyPlausible(let markerName):
            return "That \(markerName) value doesn't look like it could come from a lab report. Check the number against your paper report before saving."
        case .duplicateMarkerForDate(let markerName):
            return "You've already saved a \(markerName) result for this date. Check your results list. If you're fixing a mistake, save it under the correct date."
        }
    }
}

/// Records one marker from a paper pathology report into the patient's record.
///
/// The business operation: the patient copies a line from their report into the app.
/// Before anything is saved, the app checks the entry could really have come from a
/// lab report. Values that are merely unusual are still accepted, only the patient,
/// holding the paper, can judge those, which is why the screen asks them to confirm
/// before saving.
///
/// Business rules, checked in order:
/// 1. The healthy range must make sense (low below high, nothing negative).
/// 2. A sample cannot be collected in the future.
/// 3. A value more than 10× the top of the healthy range, or zero or below, is
///    treated as a typo rather than a result. The bound comes from the patient's own
///    report, so the app never hardcodes medical judgement.
/// 4. The same marker cannot be recorded twice for the same date.
struct RecordPathologyResultUseCase {
    let repository: HealthRecordRepository

    /// A value this many times above the healthy range's top is treated as a typo.
    static let plausibilityMultiplier: Double = 10

    /// Checks the entry against the business rules, then saves and returns the new result.
    /// Throws a `RecordPathologyResultError` naming the first rule that fails.
    @discardableResult
    func execute(
        markerName: String,
        value: Double,
        unit: String,
        referenceRange: ReferenceRange,
        collectedOn: Date,
        orderingClinician: String,
        today: Date = Date()
    ) throws -> PathologyResult {
        guard referenceRange.lowerBound >= 0,
              referenceRange.lowerBound < referenceRange.upperBound else {
            throw RecordPathologyResultError.referenceRangeInvalid
        }

        guard collectedOn <= today else {
            throw RecordPathologyResultError.collectionDateInFuture
        }

        let plausibleCeiling = referenceRange.upperBound * Self.plausibilityMultiplier
        guard value > 0, value <= plausibleCeiling else {
            throw RecordPathologyResultError.valueNotPhysiologicallyPlausible(markerName: markerName)
        }

        let alreadyRecorded = repository.results.contains { result in
            Calendar.current.isDate(result.collectedOn, inSameDayAs: collectedOn)
                && result.markers.contains {
                    $0.markerName.compare(markerName, options: .caseInsensitive) == .orderedSame
                }
        }
        guard !alreadyRecorded else {
            throw RecordPathologyResultError.duplicateMarkerForDate(markerName: markerName)
        }

        let reading = MarkerReading(
            markerName: markerName,
            value: value,
            unit: unit,
            referenceRange: referenceRange,
            plainLanguageExplanation: Self.explanation(for: markerName)
        )
        let result = PathologyResult(
            collectedOn: collectedOn,
            orderingClinician: orderingClinician,
            markers: [reading]
        )
        repository.add(result)
        return result
    }

    /// Everyday-words explanations for markers the app knows, with an honest
    /// fallback for ones it doesn't. Educational only, never medical advice.
    private static func explanation(for markerName: String) -> String {
        let glossary: [String: String] = [
            "ferritin": "Ferritin shows how much iron your body has stored. Low iron stores are a common reason for feeling tired or short of breath.",
            "haemoglobin": "Haemoglobin is the part of your red blood cells that carries oxygen around your body.",
            "vitamin d": "Vitamin D helps your body absorb calcium and keep bones and muscles strong. Most of it comes from sunlight.",
            "tsh": "TSH tells your thyroid how hard to work. It is a common check when energy levels feel off."
        ]
        return glossary[markerName.lowercased()]
            ?? "Your GP can explain what this marker measures and what your value means for you."
    }
}
