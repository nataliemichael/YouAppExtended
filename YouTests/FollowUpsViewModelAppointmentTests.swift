//
//  FollowUpsViewModelAppointmentTests.swift
//  YouTests
//

import Foundation
import Testing
@testable import You

/// Tests for the appointment questions side of `FollowUpsViewModel`: writing the
/// questions and turning them into a task.
@MainActor
struct FollowUpsViewModelAppointmentTests {

    private func days(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: n, to: Date())!
    }

    private func report(flagged: Bool) -> PathologyResult {
        let ferritin = MarkerReading(
            markerName: "Ferritin",
            value: flagged ? 9 : 90,
            unit: "µg/L",
            referenceRange: ReferenceRange(lowerBound: 30, upperBound: 300),
            plainLanguageExplanation: "Test explanation."
        )
        return PathologyResult(collectedOn: days(-5), orderingClinician: "Dr Michael", markers: [ferritin])
    }

    private func makeViewModel(flagged: Bool) -> (FollowUpsViewModel, InMemoryHealthRecordRepository) {
        let repository = InMemoryHealthRecordRepository(results: [report(flagged: flagged)], referrals: [], followUpTasks: [])
        return (FollowUpsViewModel(repository: repository), repository)
    }

    @Test func test_prepareQuestions_writesOneQuestion_forTheFlaggedMarker() {
        let (viewModel, _) = makeViewModel(flagged: true)

        let prep = viewModel.prepareQuestions(appointmentOn: days(3))

        #expect(prep?.questions.count == 1)
        #expect(prep?.questions.first?.markerName == "Ferritin")
        #expect(viewModel.errorMessage == nil)
    }

    @Test func test_prepareQuestions_explainsInPatientWords_whenNothingIsFlagged() {
        let (viewModel, _) = makeViewModel(flagged: false)

        let prep = viewModel.prepareQuestions(appointmentOn: days(3))

        #expect(prep == nil)
        #expect(viewModel.errorMessage == PrepareAppointmentQuestionsError.noFlaggedResultsToDiscuss.errorDescription)
    }

    @Test func test_addToTasks_makesOneTask_dueOnTheAppointmentDay() {
        let (viewModel, repository) = makeViewModel(flagged: true)
        let appointment = days(3)
        let prep = viewModel.prepareQuestions(appointmentOn: appointment)!

        viewModel.addToTasks(prep)

        #expect(repository.followUpTasks.count == 1)
        #expect(repository.followUpTasks.first?.dueOn == appointment)
        #expect(repository.followUpTasks.first?.title == "Take your questions to your GP appointment")
        #expect(repository.followUpTasks.first?.detail?.contains("Ferritin") == true)
        #expect(viewModel.openTasks.count == 1)
    }

    @Test func test_readingHistory_listsTheMarkerAcrossReports_oldestFirst() {
        let older = PathologyResult(
            collectedOn: days(-90), orderingClinician: "Dr Michael",
            markers: [MarkerReading(markerName: "Ferritin", value: 177, unit: "µg/L",
                                    referenceRange: ReferenceRange(lowerBound: 30, upperBound: 300),
                                    plainLanguageExplanation: "Test explanation.")]
        )
        let repository = InMemoryHealthRecordRepository(results: [report(flagged: true), older], referrals: [], followUpTasks: [])
        let viewModel = FollowUpsViewModel(repository: repository)

        let history = viewModel.readingHistory(for: "Ferritin")

        #expect(history.map(\.value) == [177, 9])
    }

    @Test func test_addToTasks_includesThePatientsOwnQuestions() {
        let (viewModel, repository) = makeViewModel(flagged: true)
        let prep = viewModel.prepareQuestions(appointmentOn: days(3))!

        viewModel.addToTasks(prep, ownQuestions: ["Should I change my diet?"])

        #expect(repository.followUpTasks.first?.detail?.contains("Should I change my diet?") == true)
        #expect(repository.followUpTasks.first?.detail?.contains("Ferritin") == true)
    }
}
