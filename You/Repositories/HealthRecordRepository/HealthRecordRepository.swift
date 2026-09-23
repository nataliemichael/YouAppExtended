//
//  HealthRecordRepository.swift
//  You
//

import Foundation

/// The patient's personal health record store.
/// The single source of truth for results, referrals and followup tasks that every screen reads from.
///
/// Business rules:
/// - There is exactly one record store per patient. Screens never keep their own copies.
/// - The store only holds and retrieves records. Deciding whether a record is valid is the job of the use cases, not the store
protocol HealthRecordRepository {
    var results: [PathologyResult] { get }
    var referrals: [Referral] { get }
    var followUpTasks: [FollowUpTask] { get }

    func add(_ result: PathologyResult)
    func add(_ referral: Referral)
    func add(_ task: FollowUpTask)
    func update(_ task: FollowUpTask)
}
