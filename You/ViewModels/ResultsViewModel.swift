//
//  ResultsViewModel.swift
//  You
//

import Foundation
import Combine

/// Connects the results screens to the record store and the recording use case.
/// Screens read `results`, ask `record(...)` to save, and show `errorMessage` when
/// something is refused.
@MainActor
final class ResultsViewModel: ObservableObject {
    @Published private(set) var results: [PathologyResult] = []
    @Published var errorMessage: String?

    private let repository: HealthRecordRepository
    private let recordResult: RecordPathologyResultUseCase

    init(repository: HealthRecordRepository) {
        self.repository = repository
        self.recordResult = RecordPathologyResultUseCase(repository: repository)
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
}
