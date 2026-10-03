//
//  ResultsViewModel.swift
//  You
//

import Foundation
import Combine
import UIKit

/// Connects the results screens to the record store and the recording use case.
/// Screens read `results`, ask `record(...)` to save, ask `readReport(...)` to lift
/// a value off a photo, and show `errorMessage` when something is refused.
@MainActor
final class ResultsViewModel: ObservableObject {
    @Published private(set) var results: [PathologyResult] = []
    @Published var errorMessage: String?

    private let repository: HealthRecordRepository
    private let recordResult: RecordPathologyResultUseCase
    private let readReportPhoto = ReadReportPhotoUseCase()
    private let textReader: ReportTextReading

    /// The app passes the Vision reader. Tests pass one that answers with fixed lines.
    init(repository: HealthRecordRepository, textReader: ReportTextReading = VisionReportTextReader()) {
        self.repository = repository
        self.recordResult = RecordPathologyResultUseCase(repository: repository)
        self.textReader = textReader
        load()
    }

    /// Re-reads the store, newest report first.
    func load() {
        results = repository.results.sorted { $0.collectedOn > $1.collectedOn }
    }

    /// Records one marker from the entry form. Returns true when saved, false when
    /// refused, in which case `errorMessage` explains why in the patient's words.
    func record(
        markerName: String,
        valueText: String,
        unit: String,
        rangeLowText: String,
        rangeHighText: String,
        collectedOn: Date,
        orderingClinician: String
    ) -> Bool {
        guard let value = Double(valueText),
              let low = Double(rangeLowText),
              let high = Double(rangeHighText) else {
            errorMessage = "The value and healthy range need to be numbers, like 9 or 30. Check what you've typed against your report."
            return false
        }

        do {
            try recordResult.execute(
                markerName: markerName.trimmingCharacters(in: .whitespaces),
                value: value,
                unit: unit.trimmingCharacters(in: .whitespaces),
                referenceRange: ReferenceRange(lowerBound: low, upperBound: high),
                collectedOn: collectedOn,
                orderingClinician: orderingClinician.trimmingCharacters(in: .whitespaces)
            )
            load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Reads one marker's value and healthy range off a photo of the report.
    /// Returns what was read, or nil when it couldn't, in which case `errorMessage`
    /// says why in the patient's words. Nothing is saved, the form fills in and the
    /// patient still confirms against the paper.
    func readReport(for marker: KnownMarker, from photo: UIImage) async -> ReportLine? {
        do {
            let lines = try await textReader.lines(in: photo)
            return try readReportPhoto.execute(marker: marker, recognisedLines: lines)
        } catch let error as ReadReportPhotoError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "We couldn't read that photo. Try another one, or type the result in from the paper."
        }
        return nil
    }
}
