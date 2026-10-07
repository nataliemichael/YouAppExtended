//
//  FollowUpsViewModel.swift
//  You
//

import Foundation
import Combine

/// Connects the Follow-ups screen to the record store and its use cases.
/// Screens read `referrals` and the task lists, ask `track(...)` to save a new
/// referral, tick tasks off through `toggleCompletion(of:)`, and ask
/// `prepareQuestions(...)` to write GP questions from the patient's flagged results.
@MainActor
final class FollowUpsViewModel: ObservableObject {
    @Published private(set) var referrals: [Referral] = []
    @Published private(set) var tasks: [FollowUpTask] = []
    @Published var errorMessage: String?

    private let repository: HealthRecordRepository
    private let trackReferral: TrackReferralUseCase
    private let prepareQuestionsUseCase: PrepareAppointmentQuestionsUseCase

    init(repository: HealthRecordRepository) {
        self.repository = repository
        self.trackReferral = TrackReferralUseCase(repository: repository)
        self.prepareQuestionsUseCase = PrepareAppointmentQuestionsUseCase(repository: repository)
        load()
    }

    /// Re-reads the store, referrals with the soonest expiry first.
    func load() {
        referrals = repository.referrals.sorted { $0.expiresOn < $1.expiresOn }
        tasks = repository.followUpTasks
    }

    /// Still-waiting tasks, most urgent first.
    var openTasks: [FollowUpTask] {
        tasks.filter { !$0.isCompleted }.sorted { $0.dueOn < $1.dueOn }
    }

    var completedTasks: [FollowUpTask] {
        tasks.filter(\.isCompleted)
    }

    /// How far ahead Home looks for things to do, matching the widget's default.
    static let upcomingWindowDays = 14

    /// Everything to do in the next fortnight, referrals to use and tasks to do,
    /// soonest first. The same list the Coming up widget shows, so they always agree.
    var upcomingActions: [PatientActionable] {
        repository.careSchedule(withinDays: Self.upcomingWindowDays)
    }

    /// The single most urgent thing the patient should do next, across referrals
    /// and tasks alike. `PatientActionable` lets one sort compare both kinds.
    var mostUrgentAction: PatientActionable? {
        let actionables: [PatientActionable] =
            referrals.filter { !$0.isExpired() } + openTasks
        return actionables.min { $0.actBy < $1.actBy }
    }

    /// Starts tracking a referral from the entry form. Returns true when saved, false
    /// when refused, in which case `errorMessage` explains why in the patient's words.
    func track(
        kind: Referral.Kind,
        purpose: String,
        issuedBy: String,
        issuedOn: Date,
        expiresOn: Date
    ) -> Bool {
        do {
            try trackReferral.execute(
                kind: kind,
                purpose: purpose.trimmingCharacters(in: .whitespaces),
                issuedBy: issuedBy.trimmingCharacters(in: .whitespaces),
                issuedOn: issuedOn,
                expiresOn: expiresOn
            )
            load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Writes the questions to ask at an appointment on `appointmentOn` from the
    /// patient's flagged results. Returns nil when there is nothing to ask or the
    /// date is wrong, in which case `errorMessage` explains why in the patient's words.
    func prepareQuestions(appointmentOn: Date) -> AppointmentPrep? {
        do {
            return try prepareQuestionsUseCase.execute(appointmentOn: appointmentOn)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Every reading of one marker across the patient's reports, oldest first, so
    /// a question can be backed by "it has been dropping for three tests".
    func readingHistory(for markerName: String) -> [MarkerReading] {
        repository.readingHistory(forMarker: markerName)
    }

    /// Turns the prepared questions, plus any the patient wrote, into one follow-up
    /// task due on the appointment day, so they show up on Follow-up, Home and the
    /// Coming up widget.
    func addToTasks(_ prep: AppointmentPrep, ownQuestions: [String] = []) {
        let lines = prep.questions.map(\.question) + ownQuestions
        let task = FollowUpTask(
            title: "Take your questions to your GP appointment",
            detail: lines.map { "• " + $0 }.joined(separator: "\n"),
            dueOn: prep.appointmentOn,
            referralID: nil
        )
        repository.add(task)
        load()
    }

    /// Marks a task done today, or clears the completion if it was ticked by mistake.
    func toggleCompletion(of task: FollowUpTask) {
        var updated = task
        updated.completedOn = task.isCompleted ? nil : Date()
        repository.update(updated)
        load()
    }
}
