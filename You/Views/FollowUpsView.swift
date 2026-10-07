//
//  FollowUpsView.swift
//  You
//

import SwiftUI
import Lottie

/// Everything the patient still needs to act on: follow-up tasks sorted by due
/// date, what they've done, and their referrals with expiry dates. Tapping a
/// task's circle marks it done.
struct FollowUpsView: View {
    @ObservedObject var viewModel: FollowUpsViewModel

    @State private var isAddingReferral = false

    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // The brand heading, same shape as Home's "Hey / You."
                VStack(alignment: .leading, spacing: -4) {
                    Text("Don't forget to")
                        .font(BrandFonts.handwriting(size: 24))
                        .foregroundStyle(AppColours.ink)
                        .padding(.leading, 4)
                    Text("Follow-up")
                        .brandTitle(size: 56)
                }
                .accessibilityElement(children: .combine)
                .padding(.horizontal, 20)

                // The referral prompt stays on the sand, outside the container.
                Button {
                    isAddingReferral = true
                } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("We'll keep track of your referrals")
                                .handwrittenHeading(size: 26)
                            Text("Tap here to add a referral and we'll turn it into a task.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .multilineTextAlignment(.leading)
                        LottieView(animation: .named("SearchDoctor"))
                            .looping()
                            .frame(width: 120, height: 120)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Track a new referral")
                .padding(.horizontal, 20)
                .padding(.bottom, 10)  // the same breath Home leaves before its box

                TileBox {
                    SectionLabel(title: "To do", systemImage: "checklist")
                    if viewModel.openTasks.isEmpty {
                        Text("Nothing waiting, you're up to date.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.horizontal, 4)
                    }
                    ForEach(viewModel.openTasks) { task in
                        taskTile(task)
                    }
                }

                if !viewModel.completedTasks.isEmpty {
                    TileBox {
                        SectionLabel(title: "Done", systemImage: "checkmark.circle")
                        ForEach(viewModel.completedTasks) { task in
                            taskTile(task)
                        }
                    }
                }

                TileBox {
                    SectionLabel(title: "Your referrals", systemImage: "doc.text")
                    if viewModel.referrals.isEmpty {
                        Text("No referrals tracked yet. Add one and the app will remind you before it expires.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.horizontal, 4)
                    }
                    ForEach(viewModel.referrals) { referral in
                        referralTile(referral)
                    }
                }

                // The heartbeat, the app's quiet sign-off at the foot of every tab.
                LottieView(animation: .named("Heartbeat"))
                    .looping()
                    .frame(width: 110, height: 110)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .background(DriftingSand())
            .sheet(isPresented: $isAddingReferral) {
                AddReferralView(viewModel: viewModel)
            }
            .onAppear {
                viewModel.load()
            }
        }
    }

    // MARK: - Tiles

    /// One referral as its own tile: what it's for as the heading, who wrote it and when it must be used.
    private func referralTile(_ referral: Referral) -> some View {
        Tile(title: referral.purpose) {
            Text("From \(referral.issuedBy)")
                .font(.subheadline)
                .tileSecondary()
            if referral.isExpired() {
                Text("Expired \(referral.expiresOn.formatted(date: .abbreviated, time: .omitted)), ask your GP for a new one")
                    .font(.subheadline)
                    .foregroundStyle(AppColours.warningOnDark)
            } else {
                Text("Use by \(referral.expiresOn.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundStyle(AppColours.warningOnDark)
            }
        }
    }

    /// One task as its own tile: tick circle on the left, title, detail and due date.
    private func taskTile(_ task: FollowUpTask) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                viewModel.toggleCompletion(of: task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? AppColours.done : Color.white.opacity(0.75))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            .accessibilityLabel(task.isCompleted ? "Mark \(task.title) as not done" : "Mark \(task.title) as done")

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .foregroundStyle(task.isCompleted ? Color.white.opacity(0.6) : Color.white)
                if let detail = task.detail {
                    Text(detail)
                        .font(.subheadline)
                        .tileSecondary()
                }
                if let completedOn = task.completedOn {
                    Text("Done \(completedOn.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .tileSecondary()
                } else if task.isOverdue() {
                    Text("Was due \(task.dueOn.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(AppColours.warningOnDark)
                } else {
                    Text("Due \(task.dueOn.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(AppColours.warningOnDark)
                }
            }
        }
        .tileBackground()
    }
}

#Preview {
    FollowUpsView(viewModel: FollowUpsViewModel(repository: InMemoryHealthRecordRepository()))
}
