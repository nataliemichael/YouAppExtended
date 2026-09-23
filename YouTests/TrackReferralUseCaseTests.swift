//
//  TrackReferralUseCaseTests.swift
//  YouTests
//

import Foundation
import Testing
@testable import You

/// Tests for `TrackReferralUseCase`, the rules that stop a referral quietly
/// expiring in a drawer. Fresh empty store and fixed dates for every test.
struct TrackReferralUseCaseTests {

    private func makeUseCase() -> (TrackReferralUseCase, InMemoryHealthRecordRepository) {
        let repository = InMemoryHealthRecordRepository(results: [], referrals: [], followUpTasks: [])
        return (TrackReferralUseCase(repository: repository), repository)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func test_trackReferral_createsFollowUp_dueThreeDaysBeforeExpiry() throws {
        let (useCase, repository) = makeUseCase()

        let referral = try useCase.execute(
            kind: .pathology,
            purpose: "Iron studies re-check",
            issuedBy: "Dr Michael",
            issuedOn: date(2026, 9, 1),
            expiresOn: date(2026, 9, 20),
            today: date(2026, 9, 4)
        )

        #expect(repository.referrals.count == 1)
        #expect(repository.followUpTasks.count == 1)

        let task = repository.followUpTasks.first
        #expect(task?.dueOn == date(2026, 9, 17))
        #expect(task?.referralID == referral.id)
    }

    @Test func test_trackReferral_remindsToday_whenExpiryIsWithinThreeDays() throws {
        let (useCase, repository) = makeUseCase()

        // Expiry is only two days away, the reminder can't be "three days before",
        // so it falls due today rather than in the past.
        try useCase.execute(
            kind: .pathology,
            purpose: "Iron studies re-check",
            issuedBy: "Dr Michael",
            issuedOn: date(2026, 9, 1),
            expiresOn: date(2026, 9, 6),
            today: date(2026, 9, 4)
        )

        #expect(repository.followUpTasks.first?.dueOn == date(2026, 9, 4))
    }

    @Test func test_trackReferral_fails_whenReferralAlreadyExpired() {
        let (useCase, repository) = makeUseCase()

        #expect(throws: TrackReferralError.referralAlreadyExpired(expiredOn: date(2026, 8, 1))) {
            try useCase.execute(
                kind: .specialist,
                purpose: "Dermatologist skin check",
                issuedBy: "Dr Michael",
                issuedOn: date(2025, 8, 1),
                expiresOn: date(2026, 8, 1),
                today: date(2026, 9, 4)
            )
        }

        #expect(repository.referrals.isEmpty)
        #expect(repository.followUpTasks.isEmpty)
    }

    @Test func test_trackReferral_fails_whenExpiryPrecedesIssueDate() {
        let (useCase, repository) = makeUseCase()

        #expect(throws: TrackReferralError.expiryBeforeIssueDate) {
            try useCase.execute(
                kind: .imaging,
                purpose: "Shoulder X-ray",
                issuedBy: "Dr Michael",
                issuedOn: date(2026, 9, 10),
                expiresOn: date(2026, 9, 5),
                today: date(2026, 9, 4)
            )
        }

        #expect(repository.referrals.isEmpty)
    }

    @Test func test_trackReferral_fails_whenSameReferralEnteredTwice() throws {
        let (useCase, repository) = makeUseCase()

        try useCase.execute(
            kind: .pathology,
            purpose: "Iron studies re-check",
            issuedBy: "Dr Michael",
            issuedOn: date(2026, 9, 1),
            expiresOn: date(2026, 9, 20),
            today: date(2026, 9, 4)
        )

        // Same referral again, purpose spelt in different case, must be refused.
        #expect(throws: TrackReferralError.duplicateReferral) {
            try useCase.execute(
                kind: .pathology,
                purpose: "iron studies re-check",
                issuedBy: "Dr Michael",
                issuedOn: date(2026, 9, 1),
                expiresOn: date(2026, 9, 20),
                today: date(2026, 9, 4)
            )
        }

        #expect(repository.referrals.count == 1)
        #expect(repository.followUpTasks.count == 1)
    }
}
