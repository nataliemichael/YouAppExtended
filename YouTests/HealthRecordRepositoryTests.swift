//
//  HealthRecordRepositoryTests.swift
//  YouTests
//

import Foundation
import Testing
@testable import You

/// Tests for the repository's domain queries, the questions the screens ask the
/// record store. Runs against the in-memory mock with fixed dates, so the Core
/// Data predicates have a plain-Swift answer to be checked against.
struct HealthRecordRepositoryTests {

    private let ferritinRange = ReferenceRange(lowerBound: 30, upperBound: 300)
    private let haemoglobinRange = ReferenceRange(lowerBound: 115, upperBound: 165)

    /// "Today" for every test: 5 September 2026.
    private var today: Date { date(2026, 9, 5) }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func task(_ title: String, dueOn: Date, completedOn: Date? = nil) -> FollowUpTask {
        FollowUpTask(title: title, detail: nil, dueOn: dueOn, completedOn: completedOn, referralID: nil)
    }

    private func referral(_ purpose: String, expiresOn: Date) -> Referral {
        Referral(kind: .pathology, purpose: purpose, issuedBy: "Dr Michael", issuedOn: date(2026, 8, 1), expiresOn: expiresOn)
    }

    private func reading(_ name: String, value: Double, range: ReferenceRange) -> MarkerReading {
        MarkerReading(markerName: name, value: value, unit: "µg/L", referenceRange: range, plainLanguageExplanation: "Test explanation.")
    }

    private func report(on collectedOn: Date, _ markers: [MarkerReading]) -> PathologyResult {
        PathologyResult(collectedOn: collectedOn, orderingClinician: "Dr Michael", markers: markers)
    }

    private func emptyStore() -> InMemoryHealthRecordRepository {
        InMemoryHealthRecordRepository(results: [], referrals: [], followUpTasks: [])
    }

    // MARK: - "What do I need to do soon?"

    @Test func test_tasksDueSoon_includesTaskDueExactlySevenDaysOut() {
        let store = emptyStore()
        store.add(task("Book the iron studies blood test", dueOn: date(2026, 9, 12)))  // day 7 exactly

        let due = store.followUpTasksDue(withinDays: 7, on: today)

        #expect(due.map(\.title) == ["Book the iron studies blood test"])
    }

    @Test func test_tasksDueSoon_stillListsOverdueTask() {
        let store = emptyStore()
        store.add(task("Pick up pathology request form", dueOn: date(2026, 8, 28)))  // a week late
        store.add(task("Ask Dr Michael about low ferritin", dueOn: date(2026, 9, 8)))

        let due = store.followUpTasksDue(withinDays: 7, on: today)

        // Overdue first, then the one due this week.
        #expect(due.map(\.title) == ["Pick up pathology request form", "Ask Dr Michael about low ferritin"])
    }

    @Test func test_tasksDueSoon_ignoresCompletedTask() {
        let store = emptyStore()
        store.add(task("Pick up pathology request form", dueOn: date(2026, 9, 6), completedOn: date(2026, 9, 4)))
        store.add(task("Book the iron studies blood test", dueOn: date(2026, 9, 6)))

        let due = store.followUpTasksDue(withinDays: 7, on: today)

        #expect(due.map(\.title) == ["Book the iron studies blood test"])
    }

    // MARK: - "Which referrals am I about to lose?"

    @Test func test_referralsExpiring_includesReferralExpiringToday() {
        let store = emptyStore()
        store.add(referral("Iron studies re-check", expiresOn: date(2026, 9, 12)))
        store.add(referral("Dermatologist skin check", expiresOn: today))  // last usable day

        let expiring = store.referralsExpiring(withinDays: 14, on: today)

        // Today's one is the most urgent, so it comes first.
        #expect(expiring.map(\.purpose) == ["Dermatologist skin check", "Iron studies re-check"])
    }

    @Test func test_referralsExpiring_ignoresReferralOutsideWindow() {
        let store = emptyStore()
        store.add(referral("Shoulder X-ray", expiresOn: date(2026, 9, 20)))            // day 15, too far
        store.add(referral("Dermatologist skin check", expiresOn: date(2026, 9, 4)))  // expired yesterday
        store.add(referral("Iron studies re-check", expiresOn: date(2026, 9, 19)))    // day 14, in

        let expiring = store.referralsExpiring(withinDays: 14, on: today)

        #expect(expiring.map(\.purpose) == ["Iron studies re-check"])
    }

    // MARK: - "Which results should I raise with my GP?"

    @Test func test_flaggedReadings_returnsOnlyOutOfRangeReadingsFromRecentReportsNewestFirst() {
        let store = emptyStore()
        store.add(report(on: date(2025, 6, 1), [reading("Ferritin", value: 12, range: ferritinRange)]))  // too old
        store.add(report(on: date(2026, 6, 1), [reading("Ferritin", value: 15, range: ferritinRange)]))
        store.add(report(on: date(2026, 8, 30), [
            reading("Ferritin", value: 9, range: ferritinRange),           // flagged
            reading("Haemoglobin", value: 138, range: haemoglobinRange)    // healthy
        ]))

        let flagged = store.flaggedReadings(since: date(2025, 9, 5))

        // Two ferritin readings, newest first, no haemoglobin, nothing from 2025.
        #expect(flagged.map(\.value) == [9, 15])
        #expect(flagged.allSatisfy { $0.markerName == "Ferritin" })
    }

    // MARK: - "Is this getting better?"

    @Test func test_readingHistory_listsOneMarkerAcrossReportsOldestFirst() {
        let store = emptyStore()
        store.add(report(on: date(2026, 8, 30), [reading("Ferritin", value: 9, range: ferritinRange)]))
        store.add(report(on: date(2026, 3, 1), [
            reading("Ferritin", value: 12, range: ferritinRange),
            reading("Haemoglobin", value: 138, range: haemoglobinRange)
        ]))
        store.add(report(on: date(2026, 6, 1), [reading("Ferritin", value: 15, range: ferritinRange)]))

        let history = store.readingHistory(forMarker: "Ferritin")

        // Oldest first so the trend reads left to right, haemoglobin not mixed in.
        #expect(history.map(\.value) == [12, 15, 9])
    }

    @Test func test_readingHistory_matchesMarkerNameRegardlessOfCase() {
        let store = emptyStore()
        store.add(report(on: date(2026, 6, 1), [reading("ferritin", value: 15, range: ferritinRange)]))
        store.add(report(on: date(2026, 8, 30), [reading("Ferritin", value: 9, range: ferritinRange)]))

        let history = store.readingHistory(forMarker: "FERRITIN")

        #expect(history.count == 2)
    }

    @Test func test_readingHistory_isEmptyForMarkerNeverMeasured() {
        let store = emptyStore()
        store.add(report(on: date(2026, 8, 30), [reading("Ferritin", value: 9, range: ferritinRange)]))

        #expect(store.readingHistory(forMarker: "TSH").isEmpty)
    }
}
