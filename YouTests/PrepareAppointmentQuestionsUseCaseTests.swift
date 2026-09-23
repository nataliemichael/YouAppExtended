//
//  PrepareAppointmentQuestionsUseCaseTests.swift
//  YouTests
//

import Foundation
import Testing
@testable import You

/// Tests for `PrepareAppointmentQuestionsUseCase`, turning flagged results into
/// GP questions. Fresh empty store and fixed dates for every test.
struct PrepareAppointmentQuestionsUseCaseTests {

    private let ferritinRange = ReferenceRange(lowerBound: 30, upperBound: 300)
    private let haemoglobinRange = ReferenceRange(lowerBound: 115, upperBound: 165)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func reading(_ name: String, value: Double, range: ReferenceRange) -> MarkerReading {
        MarkerReading(
            markerName: name,
            value: value,
            unit: "µg/L",
            referenceRange: range,
            plainLanguageExplanation: "Test explanation."
        )
    }

    private func makeUseCase(results: [PathologyResult]) -> PrepareAppointmentQuestionsUseCase {
        let repository = InMemoryHealthRecordRepository(results: results, referrals: [], followUpTasks: [])
        return PrepareAppointmentQuestionsUseCase(repository: repository)
    }

    @Test func test_prepareQuestions_generatesOneQuestionPerFlaggedMarker() throws {
        let result = PathologyResult(
            collectedOn: date(2026, 8, 30),
            orderingClinician: "Dr Michael",
            markers: [
                reading("Ferritin", value: 9, range: ferritinRange),        // flagged
                reading("Haemoglobin", value: 138, range: haemoglobinRange) // healthy
            ]
        )
        let useCase = makeUseCase(results: [result])

        let prep = try useCase.execute(appointmentOn: date(2026, 9, 10), today: date(2026, 9, 5))

        #expect(prep.questions.count == 1)
        #expect(prep.questions.first?.markerName == "Ferritin")
        #expect(prep.questions.first?.question.contains("below the healthy range") == true)
    }

    @Test func test_prepareQuestions_usesMostRecentReading_whenMarkerFlaggedTwice() throws {
        let older = PathologyResult(
            collectedOn: date(2026, 6, 1),
            orderingClinician: "Dr Michael",
            markers: [reading("Ferritin", value: 12, range: ferritinRange)]
        )
        let newer = PathologyResult(
            collectedOn: date(2026, 8, 30),
            orderingClinician: "Dr Michael",
            markers: [reading("Ferritin", value: 9, range: ferritinRange)]
        )
        let useCase = makeUseCase(results: [older, newer])

        let prep = try useCase.execute(appointmentOn: date(2026, 9, 10), today: date(2026, 9, 5))

        // One question only, quoting the newer value 9, not the older 12.
        #expect(prep.questions.count == 1)
        #expect(prep.questions.first?.question.contains("was 9 ") == true)
    }

    @Test func test_prepareQuestions_fails_whenNoMarkersFlagged() {
        let allHealthy = PathologyResult(
            collectedOn: date(2026, 8, 30),
            orderingClinician: "Dr Michael",
            markers: [reading("Haemoglobin", value: 138, range: haemoglobinRange)]
        )
        let useCase = makeUseCase(results: [allHealthy])

        #expect(throws: PrepareAppointmentQuestionsError.noFlaggedResultsToDiscuss) {
            try useCase.execute(appointmentOn: date(2026, 9, 10), today: date(2026, 9, 5))
        }
    }

    @Test func test_prepareQuestions_fails_whenAppointmentIsInPast() {
        let useCase = makeUseCase(results: [])

        #expect(throws: PrepareAppointmentQuestionsError.appointmentDateInPast) {
            try useCase.execute(appointmentOn: date(2026, 9, 1), today: date(2026, 9, 5))
        }
    }

    @Test func test_prepareQuestions_fails_whenFlaggedResultsOlderThanTwelveMonths() {
        let stale = PathologyResult(
            collectedOn: date(2025, 6, 1),
            orderingClinician: "Dr Michael",
            markers: [reading("Ferritin", value: 9, range: ferritinRange)]
        )
        let useCase = makeUseCase(results: [stale])

        #expect(throws: PrepareAppointmentQuestionsError.resultsOlderThanTwelveMonths) {
            try useCase.execute(appointmentOn: date(2026, 9, 10), today: date(2026, 9, 5))
        }
    }
}
