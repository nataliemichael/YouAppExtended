//
//  HealthRecordRepository.swift
//  You
//

import Foundation

/// The patient's personal health record store.
/// The single source of truth for results, referrals and follow-up tasks that every screen reads from.
///
/// Business rules:
/// - There is exactly one record store per patient. Screens never keep their own copies.
/// - The store only holds and retrieves records. Deciding whether a record is valid is the job of the use cases, not the store.
/// - Views and ViewModels only ever see this protocol. Which technology sits behind it
///   (Core Data in the app, in-memory in tests) is the store's own business.
protocol HealthRecordRepository {
    var results: [PathologyResult] { get }
    var referrals: [Referral] { get }
    var followUpTasks: [FollowUpTask] { get }

    func add(_ result: PathologyResult)
    func add(_ referral: Referral)
    func add(_ task: FollowUpTask)
    func update(_ task: FollowUpTask)

    /// Removes a report the patient entered by mistake, together with its readings.
    func delete(_ result: PathologyResult)

    // MARK: - Domain queries
    // Each of these answers a question the patient actually asks.

    /// "What do I need to do soon?" Open tasks due on or before `days` from `date`,
    /// soonest first. Overdue tasks count too, they still need doing.
    func followUpTasksDue(withinDays days: Int, on date: Date) -> [FollowUpTask]

    /// "Which referrals am I about to lose?" Referrals still valid on `date` that
    /// expire within `days`, soonest expiry first.
    func referralsExpiring(withinDays days: Int, on date: Date) -> [Referral]

    /// "Which results should I raise with my GP?" Readings outside their healthy
    /// range from reports collected on or after `since`.
    func flaggedReadings(since: Date) -> [MarkerReading]
}
