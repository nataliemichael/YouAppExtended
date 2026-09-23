//
//  PatientActionableTests.swift
//  YouTests
//

import Foundation
import Testing
@testable import You

/// Tests for `PatientActionable`, the shared deadline behaviour of referrals and
/// follow-up tasks. Uses far-future dates so referral expiry checks stay stable.
struct PatientActionableTests {

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @MainActor
    @Test func test_mostUrgentAction_picksEarliestAcrossReferralsAndTasks() {
        let referral = Referral(
            kind: .pathology,
            purpose: "Iron studies re-check",
            issuedBy: "Dr Michael",
            issuedOn: date(2030, 1, 1),
            expiresOn: date(2030, 3, 1)
        )
        let soonerTask = FollowUpTask(
            title: "Book the iron studies blood test",
            detail: nil,
            dueOn: date(2030, 2, 1),
            referralID: referral.id
        )
        let repository = InMemoryHealthRecordRepository(
            results: [],
            referrals: [referral],
            followUpTasks: [soonerTask]
        )
        let viewModel = FollowUpsViewModel(repository: repository)

        // The task is due a month before the referral expires, so it wins.
        #expect(viewModel.mostUrgentAction?.actBy == date(2030, 2, 1))
        #expect(viewModel.mostUrgentAction?.patientAction == "Book the iron studies blood test")
    }

    @MainActor
    @Test func test_mostUrgentAction_isReferral_whenItExpiresBeforeAnyTaskIsDue() {
        let referral = Referral(
            kind: .specialist,
            purpose: "Dermatologist skin check",
            issuedBy: "Dr Michael",
            issuedOn: date(2030, 1, 1),
            expiresOn: date(2030, 1, 20)
        )
        let laterTask = FollowUpTask(
            title: "Ask Dr Michael about low ferritin",
            detail: nil,
            dueOn: date(2030, 2, 1),
            referralID: nil
        )
        let repository = InMemoryHealthRecordRepository(
            results: [],
            referrals: [referral],
            followUpTasks: [laterTask]
        )
        let viewModel = FollowUpsViewModel(repository: repository)

        #expect(viewModel.mostUrgentAction?.patientAction == "Use your referral: Dermatologist skin check")
    }
}
