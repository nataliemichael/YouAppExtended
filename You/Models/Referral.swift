//
//  Referral.swift
//  You
//

import Foundation

/// A referral or test request a GP hands to the patient, e.g. a pathology request form or a letter to a specialist.
///
/// Business rules:
/// - A referral is only valid from `issuedOn` until `expiresOn`. Labs and specialists refuse expired referrals, so the patient must act before the window closes.
/// - Expiry can never come before the issue date (enforced by `TrackReferralUseCase`).
struct Referral: Identifiable, Codable, Hashable {
    var id: UUID = UUID()

    /// The kind of service the referral is for.
    enum Kind: String, Codable, CaseIterable {
        case pathology
        case specialist
        case imaging
    }

    let kind: Kind

    /// What the referral is for, as the patient would say it, e.g. "Iron studies re-check"
    let purpose: String

    /// The clinician who wrote the referral, e.g. "Dr Michael".
    let issuedBy: String

    /// The day the referral was written.
    let issuedOn: Date

    /// The last day the referral will be accepted.
    let expiresOn: Date

    /// True when the referral is past its expiry and a new one is needed from the GP.
    func isExpired(on date: Date = Date()) -> Bool {
        date > expiresOn
    }
}
