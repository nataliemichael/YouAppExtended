//
//  TrackReferralUseCase.swift
//  You
//

import Foundation

/// The reasons tracking a referral can fail, each written for the patient with a way forward.
enum TrackReferralError: LocalizedError, Equatable {
    /// The expiry date is earlier than the day the referral was written.
    case expiryBeforeIssueDate
    /// The referral's expiry date has already passed.
    case referralAlreadyExpired(expiredOn: Date)
    /// This referral is already being tracked.
    case duplicateReferral

    var errorDescription: String? {
        switch self {
        case .expiryBeforeIssueDate:
            return "The expiry date is before the day the referral was written. Check both dates on the paper and try again."
        case .referralAlreadyExpired(let expiredOn):
            return "This referral expired on \(expiredOn.formatted(date: .abbreviated, time: .omitted)). You'll need a new one from your GP before it can be used."
        case .duplicateReferral:
            return "You're already tracking this referral. Check your Follow-ups list."
        }
    }
}

/// Starts tracking a referral the patient was handed, so it can't quietly expire in a drawer.
///
/// The business operation: the patient copies the details from a paper referral into
/// the app. If the referral is still usable, the app saves it and books a follow-up
/// task reminding the patient to act three days before it expires, or today, when
/// the expiry is closer than that.
///
/// Business rules, checked in order:
/// 1. A referral cannot expire before it was written.
/// 2. An already-expired referral cannot be tracked, the patient needs a new one,
///    and the app says so rather than storing a dead document.
/// 3. The same referral (same kind, purpose and issue date) is only tracked once.
struct TrackReferralUseCase {
    let repository: HealthRecordRepository

    /// How many days before expiry the follow-up task falls due.
    static let reminderLeadDays = 3

    /// Checks the referral against the business rules, then saves it together with
    /// its follow-up task. Throws a `TrackReferralError` naming the first rule that fails.
    @discardableResult
    func execute(
        kind: Referral.Kind,
        purpose: String,
        issuedBy: String,
        issuedOn: Date,
        expiresOn: Date,
        today: Date = Date()
    ) throws -> Referral {
        guard expiresOn >= issuedOn else {
            throw TrackReferralError.expiryBeforeIssueDate
        }

        guard expiresOn >= today else {
            throw TrackReferralError.referralAlreadyExpired(expiredOn: expiresOn)
        }

        let calendar = Calendar.current
        let alreadyTracked = repository.referrals.contains { existing in
            existing.kind == kind
                && existing.purpose.compare(purpose, options: .caseInsensitive) == .orderedSame
                && calendar.isDate(existing.issuedOn, inSameDayAs: issuedOn)
        }
        guard !alreadyTracked else {
            throw TrackReferralError.duplicateReferral
        }

        let referral = Referral(
            kind: kind,
            purpose: purpose,
            issuedBy: issuedBy,
            issuedOn: issuedOn,
            expiresOn: expiresOn
        )

        let threeDaysBefore = calendar.date(
            byAdding: .day,
            value: -Self.reminderLeadDays,
            to: expiresOn
        ) ?? expiresOn
        let task = FollowUpTask(
            title: "Book: \(purpose)",
            detail: "Your referral from \(issuedBy) expires on \(expiresOn.formatted(date: .abbreviated, time: .omitted)).",
            dueOn: max(today, threeDaysBefore),
            referralID: referral.id
        )

        repository.add(referral)
        repository.add(task)
        return referral
    }
}
