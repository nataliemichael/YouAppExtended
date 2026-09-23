//
//  FollowUpTask.swift
//  You
//

import Foundation

/// A dated action the patient needs to complete, e.g. "Book the iron studies blood test".
///
/// Business rules:
/// - A task is either created from a referral (so acting on it uses the referral before it expires) or from a flagged result the patient wants to raise with their GP.
/// - Completion is recorded as a date, not a tick, so the patient's history shows when things were actually done.
struct FollowUpTask: Identifiable, Codable, Hashable {
    var id: UUID = UUID()

    /// The action in the patient's words, e.g. "Book the iron studies blood test".
    let title: String

    /// Extra help for getting it done, e.g. where walk-in collection centres are.
    let detail: String?

    /// The day this should be done by.
    let dueOn: Date

    /// The day it was completed, or nil while it is still waiting.
    var completedOn: Date? = nil

    /// The referral this task came from, when it came from one.
    let referralID: UUID?

    var isCompleted: Bool {
        completedOn != nil
    }

    /// True when the due date has passed and the task is still not done.
    func isOverdue(on date: Date = Date()) -> Bool {
        !isCompleted && date > dueOn
    }
}
