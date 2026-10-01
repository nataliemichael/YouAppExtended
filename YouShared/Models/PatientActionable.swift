//
//  PatientActionable.swift
//  You
//

import Foundation

/// Anything in the patient's record that carries a deadline the patient must act on.
///
/// Business rule: referrals and follow-up tasks are different documents, but to the
/// patient they are the same kind of thing, something to do by a date. This protocol
/// captures that shared behaviour so the app can find the single most urgent action
/// across both.
protocol PatientActionable {
    /// What the patient needs to do, in their words.
    var patientAction: String { get }

    /// The date it must be done by.
    var actBy: Date { get }

    /// True when the deadline has passed and the action still matters.
    func isOverdue(on date: Date) -> Bool
}

extension Referral: PatientActionable {
    var patientAction: String { "Use your referral: \(purpose)" }
    var actBy: Date { expiresOn }
    func isOverdue(on date: Date) -> Bool { isExpired(on: date) }
}

extension FollowUpTask: PatientActionable {
    var patientAction: String { title }
    var actBy: Date { dueOn }
    // isOverdue(on:) already exists on FollowUpTask and satisfies the protocol.
}
