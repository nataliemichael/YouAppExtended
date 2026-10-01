//
//  SampleData.swift
//  You
//

import Foundation

/// Hardcoded sample records for building the screens against real domain types.
/// Becomes the seed data for the repository once the storage layer exists.
enum SampleData {

    private static func days(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
    }

    // MARK: - Markers

    static let lowFerritin = MarkerReading(
        markerName: "Ferritin",
        value: 9,
        unit: "µg/L",
        referenceRange: ReferenceRange(lowerBound: 30, upperBound: 300),
        plainLanguageExplanation: "Ferritin shows how much iron your body has stored. Low iron stores are a common reason for feeling tired or short of breath."
    )

    static let haemoglobin = MarkerReading(
        markerName: "Haemoglobin",
        value: 138,
        unit: "g/L",
        referenceRange: ReferenceRange(lowerBound: 115, upperBound: 165),
        plainLanguageExplanation: "Haemoglobin is the part of your red blood cells that carries oxygen around your body."
    )

    static let vitaminD = MarkerReading(
        markerName: "Vitamin D",
        value: 51,
        unit: "nmol/L",
        referenceRange: ReferenceRange(lowerBound: 50, upperBound: 140),
        plainLanguageExplanation: "Vitamin D helps your body absorb calcium and keep bones and muscles strong. Most of it comes from sunlight."
    )

    static let thyroid = MarkerReading(
        markerName: "TSH",
        value: 2.1,
        unit: "mIU/L",
        referenceRange: ReferenceRange(lowerBound: 0.5, upperBound: 4.0),
        plainLanguageExplanation: "TSH tells your thyroid how hard to work. It is a common check when energy levels feel off."
    )

    // MARK: - Results

    static let results: [PathologyResult] = [
        PathologyResult(
            collectedOn: days(-5),
            orderingClinician: "Dr Michael",
            markers: [lowFerritin, haemoglobin, vitaminD]
        ),
        PathologyResult(
            collectedOn: days(-96),
            orderingClinician: "Dr Michael",
            markers: [haemoglobin, thyroid]
        )
    ]

    // MARK: - Referrals

    static let ironStudiesReferral = Referral(
        kind: .pathology,
        purpose: "Iron studies re-check",
        issuedBy: "Dr Michael",
        issuedOn: days(-5),
        expiresOn: days(12)
    )

    static let expiredSkinCheckReferral = Referral(
        kind: .specialist,
        purpose: "Dermatologist skin check",
        issuedBy: "Dr Michael",
        issuedOn: days(-400),
        expiresOn: days(-35)
    )

    static let referrals: [Referral] = [ironStudiesReferral, expiredSkinCheckReferral]

    // MARK: - Follow-up tasks

    static let followUpTasks: [FollowUpTask] = [
        FollowUpTask(
            title: "Book the iron studies blood test",
            detail: "Your request form expires soon. Most collection centres take walk-ins, bring the paper form.",
            dueOn: days(3),
            referralID: ironStudiesReferral.id
        ),
        FollowUpTask(
            title: "Ask Dr Michael about low ferritin",
            detail: "Your ferritin came back below the healthy range on your last test.",
            dueOn: days(7),
            referralID: nil
        ),
        FollowUpTask(
            title: "Pick up pathology request form",
            detail: nil,
            dueOn: days(-2),
            completedOn: days(-2),
            referralID: ironStudiesReferral.id
        )
    ]
}
