//
//  InMemoryHealthRecordRepository.swift
//  You
//

import Foundation

/// A health record store that lasts until the app closes. The unit tests need a
/// store they can set up in a known state instantly, so this is the mock every
/// use case and ViewModel test runs against. Previews use it too.
final class InMemoryHealthRecordRepository: HealthRecordRepository {
    private(set) var results: [PathologyResult]
    private(set) var referrals: [Referral]
    private(set) var followUpTasks: [FollowUpTask]

    init(
        results: [PathologyResult] = SampleData.results,
        referrals: [Referral] = SampleData.referrals,
        followUpTasks: [FollowUpTask] = SampleData.followUpTasks
    ) {
        self.results = results
        self.referrals = referrals
        self.followUpTasks = followUpTasks
    }

    func add(_ result: PathologyResult) {
        results.append(result)
    }

    func add(_ referral: Referral) {
        referrals.append(referral)
    }

    func add(_ task: FollowUpTask) {
        followUpTasks.append(task)
    }

    func update(_ task: FollowUpTask) {
        guard let index = followUpTasks.firstIndex(where: { $0.id == task.id }) else { return }
        followUpTasks[index] = task
    }

    func delete(_ result: PathologyResult) {
        results.removeAll { $0.id == result.id }
    }

    // MARK: - Domain queries
    // Plain Swift filters that must match the Core Data predicates exactly.

    func followUpTasksDue(withinDays days: Int, on date: Date) -> [FollowUpTask] {
        let cutoff = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
        return followUpTasks
            .filter { !$0.isCompleted && $0.dueOn <= cutoff }
            .sorted { $0.dueOn < $1.dueOn }
    }

    func referralsExpiring(withinDays days: Int, on date: Date) -> [Referral] {
        let today = Calendar.current.startOfDay(for: date)
        let cutoff = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
        return referrals
            .filter { $0.expiresOn >= today && $0.expiresOn <= cutoff }
            .sorted { $0.expiresOn < $1.expiresOn }
    }

    func flaggedReadings(since: Date) -> [MarkerReading] {
        results
            .filter { $0.collectedOn >= since }
            .sorted { $0.collectedOn > $1.collectedOn }
            .flatMap(\.flaggedMarkers)
    }

    func readingHistory(forMarker markerName: String) -> [MarkerReading] {
        results
            .sorted { $0.collectedOn < $1.collectedOn }
            .flatMap(\.markers)
            .filter { $0.markerName.compare(markerName, options: .caseInsensitive) == .orderedSame }
    }
}
