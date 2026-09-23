//
//  FollowUpsViewModel.swift
//  You
//

import Foundation
import Combine

/// Connects the Follow-ups screen to the record store and the referral use case.
/// Screens read `referrals` and the task lists, ask `track(...)` to save a new
/// referral, and tick tasks off through `toggleCompletion(of:)`.
@MainActor
final class FollowUpsViewModel: ObservableObject {
    @Published private(set) var referrals: [Referral] = []
    @Published private(set) var tasks: [FollowUpTask] = []
    @Published var errorMessage: String?

    private let repository: HealthRecordRepository
    private let trackReferral: TrackReferralUseCase

    init(repository: HealthRecordRepository) {
        self.repository = repository
        self.trackReferral = TrackReferralUseCase(repository: repository)
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

    /// Marks a task done today, or clears the completion if it was ticked by mistake.
    func toggleCompletion(of task: FollowUpTask) {
        var updated = task
        updated.completedOn = task.isCompleted ? nil : Date()
        repository.update(updated)
        load()
    }
}
