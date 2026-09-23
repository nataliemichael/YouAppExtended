//
//  YouTests.swift
//  YouTests
//
//  Created by Natalie Michael on 31/8/2026.
//

import Foundation
import Testing
@testable import You

/// Tests for `RecordPathologyResultUseCase`, the business rules for typing a
/// marker in from a paper report. Each test starts from an empty record store
/// and uses fixed dates so results never depend on when the tests run.
struct RecordPathologyResultUseCaseTests {

    /// The healthy range for ferritin used across these tests, as a lab prints it.
    private let ferritinRange = ReferenceRange(lowerBound: 30, upperBound: 300)

    private func makeUseCase() -> (RecordPathologyResultUseCase, InMemoryHealthRecordRepository) {
        let repository = InMemoryHealthRecordRepository(results: [], referrals: [], followUpTasks: [])
        return (RecordPathologyResultUseCase(repository: repository), repository)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func test_recordResult_flagsFerritin_whenBelowReferenceRange() throws {
        let (useCase, repository) = makeUseCase()

        let result = try useCase.execute(
            markerName: "Ferritin",
            value: 9,
            unit: "µg/L",
            referenceRange: ferritinRange,
            collectedOn: date(2026, 9, 1),
            orderingClinician: "Dr Michael",
            today: date(2026, 9, 3)
        )

        #expect(repository.results.count == 1)
        #expect(result.flaggedMarkers.count == 1)
        #expect(result.markers.first?.status == .belowRange)
    }

    @Test func test_recordResult_succeeds_atExactLowerBoundOfRange() throws {
        let (useCase, _) = makeUseCase()

        // Labs treat a value sitting exactly on the bound as within range,
        // so 30 against a 30–300 range must not be flagged.
        let result = try useCase.execute(
            markerName: "Ferritin",
            value: 30,
            unit: "µg/L",
            referenceRange: ferritinRange,
            collectedOn: date(2026, 9, 1),
            orderingClinician: "Dr Michael",
            today: date(2026, 9, 3)
        )

        #expect(result.flaggedMarkers.isEmpty)
        #expect(result.markers.first?.status == .inRange)
    }

    @Test func test_recordResult_fails_whenValueIsPhysiologicallyImpossible() {
        let (useCase, repository) = makeUseCase()

        // 4000 is more than 10× the top of the 30–300 range, a typo, not a result.
        #expect(throws: RecordPathologyResultError.valueNotPhysiologicallyPlausible(markerName: "Ferritin")) {
            try useCase.execute(
                markerName: "Ferritin",
                value: 4000,
                unit: "µg/L",
                referenceRange: ferritinRange,
                collectedOn: date(2026, 9, 1),
                orderingClinician: "Dr Michael",
                today: date(2026, 9, 3)
            )
        }

        #expect(repository.results.isEmpty)
    }

    @Test func test_recordResult_fails_whenSameMarkerAlreadyRecordedForDate() throws {
        let (useCase, repository) = makeUseCase()

        try useCase.execute(
            markerName: "Ferritin",
            value: 9,
            unit: "µg/L",
            referenceRange: ferritinRange,
            collectedOn: date(2026, 9, 1),
            orderingClinician: "Dr Michael",
            today: date(2026, 9, 3)
        )

        // Same marker, same date, even spelt differently, must be refused.
        #expect(throws: RecordPathologyResultError.duplicateMarkerForDate(markerName: "ferritin")) {
            try useCase.execute(
                markerName: "ferritin",
                value: 12,
                unit: "µg/L",
                referenceRange: ferritinRange,
                collectedOn: date(2026, 9, 1),
                orderingClinician: "Dr Michael",
                today: date(2026, 9, 3)
            )
        }

        #expect(repository.results.count == 1)
    }

    @Test func test_recordResult_fails_whenCollectionDateIsInFuture() {
        let (useCase, repository) = makeUseCase()

        #expect(throws: RecordPathologyResultError.collectionDateInFuture) {
            try useCase.execute(
                markerName: "Ferritin",
                value: 90,
                unit: "µg/L",
                referenceRange: ferritinRange,
                collectedOn: date(2026, 9, 10),
                orderingClinician: "Dr Michael",
                today: date(2026, 9, 3)
            )
        }

        #expect(repository.results.isEmpty)
    }
}
