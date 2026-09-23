//
//  InMemoryHealthRecordRepository.swift
//  You
//

import Foundation

/// A health record store Data lasts until the app closes. The unit tests need a store they can set up in a known state instantly, and allows me to build and test all three use cases without touching file storage.
/// 
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
}
