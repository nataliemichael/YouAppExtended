//
//  HomeView.swift
//  You
//

import SwiftUI
import UIKit
import Lottie

/// The first screen: a greeting, what needs the patient's attention right now,
/// reports shared in from other apps, and getting ready for the next GP visit.
/// Results and follow-ups have their own tabs.
struct HomeView: View {
    @ObservedObject var resultsViewModel: ResultsViewModel
    @ObservedObject var followUpsViewModel: FollowUpsViewModel

    @State private var openedSharedReport: OpenedSharedReport?
    @State private var isPreparingQuestions = false
    @Environment(\.scenePhase) private var scenePhase

    /// A shared report the patient tapped, with its photo ready for the form.
    private struct OpenedSharedReport: Identifiable {
        let report: SharedReport
        let photo: UIImage
        var id: String { report.id }
    }

    /// The patient's first name, kept in UserDefaults. A display preference lives
    /// here; health records belong in the repository, not UserDefaults.
    @AppStorage("patientFirstName") private var patientFirstName = ""
    @State private var isEditingName = false
    @State private var nameDraft = ""

    private var greeting: String {
        patientFirstName.isEmpty ? "Welcome back" : "Welcome back, \(patientFirstName)"
    }

    /// Flagged markers from the most recent report.
    private var attentionMarkers: [MarkerReading] {
        resultsViewModel.results.first?.flaggedMarkers ?? []
    }

    private var hasSomethingToShow: Bool {
        !attentionMarkers.isEmpty || !followUpsViewModel.upcomingActions.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                heading
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)  // a clear gap before the GP prompt

                Button {
                    isPreparingQuestions = true
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Seeing your GP soon?")
                            .handwrittenHeading(size: 26)
                        Text("Tap here and we'll write your questions from your results.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Prepare questions for your GP appointment")
                .padding(.horizontal, 20)
                .padding(.bottom, 10)  // the same breath the other tabs leave before their first box

                attentionBox
                if !resultsViewModel.sharedReports.isEmpty {
                    sharedBox
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
            .sheet(item: $openedSharedReport) { opened in
                RecordResultView(viewModel: resultsViewModel, sharedReport: opened.report, sharedPhoto: opened.photo)
            }
            .sheet(isPresented: $isPreparingQuestions) {
                AppointmentQuestionsView(viewModel: followUpsViewModel)
            }
            .alert("Couldn't open that report", isPresented: sharedReportErrorBinding) {
                Button("OK") {}
            } message: {
                Text(resultsViewModel.errorMessage ?? "")
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { resultsViewModel.load() }  // a report may have been shared in while we were away
            }
            .alert("What should we call you?", isPresented: $isEditingName) {
                TextField("Your name", text: $nameDraft)
                Button("Save") {
                    patientFirstName = nameDraft.trimmingCharacters(in: .whitespaces)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Just for your greeting. It stays on your device, like everything else.")
            }
            .onAppear {
                resultsViewModel.load()
                followUpsViewModel.load()
            }
        }
    }

    // MARK: - Heading

    private var heading: some View {
        VStack(alignment: .leading, spacing: 10) {
            // The brand heading with the waving figure beside it.
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: -4) {
                    Text("Hey")
                        .font(BrandFonts.handwriting(size: 30))
                        .foregroundStyle(AppColours.ink)
                        .padding(.leading, 4)
                    Text("You.")
                        .brandTitle(size: 56)
                }
                .accessibilityElement(children: .combine)
                LottieView(animation: .named("Waving"))
                    .looping()
                    .frame(width: 130, height: 112)
                Spacer(minLength: 0)
            }

            // The greeting, tappable to set the patient's name.
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColours.ink)
                Text(patientFirstName.isEmpty
                    ? "Tap here to tell us your name."
                    : "Here's where your health is at today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                nameDraft = patientFirstName
                isEditingName = true
            }
        }
    }

    // MARK: - Boxes, laid out like To do and Done on Follow-up

    private var attentionBox: some View {
        TileBox {
            SectionLabel(title: "Needs your attention", systemImage: "bell")
            if !hasSomethingToShow {
                Text("Nothing needs doing right now. Your results and follow-ups are in the tabs below.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 4)
            }
            // Results outside their healthy range on the latest report
            ForEach(attentionMarkers) { reading in
                Label {
                    Text("\(reading.markerName) is outside the healthy range")
                } icon: {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(AppColours.warningOnDark)
                }
                .tileBackground()
            }
            // Referrals to use and tasks to do in the next fortnight, soonest first
            ForEach(Array(followUpsViewModel.upcomingActions.enumerated()), id: \.offset) { _, action in
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.patientAction)
                        .font(.headline)
                    Text(action.isOverdue(on: Date())
                        ? "Was due \(action.actBy.formatted(date: .abbreviated, time: .omitted))"
                        : "By \(action.actBy.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundStyle(AppColours.warningOnDark)
                }
                .tileBackground()
            }
        }
    }

    private var sharedBox: some View {
        TileBox {
            SectionLabel(title: "Shared to You", systemImage: "square.and.arrow.down")
            ForEach(resultsViewModel.sharedReports) { report in
                sharedReportRow(report)
                    .tileBackground()
            }
        }
    }

    /// One report waiting in the inbox: a thumbnail, when it arrived, and what to do.
    private func sharedReportRow(_ report: SharedReport) -> some View {
        Button {
            if let photo = resultsViewModel.openSharedReport(report) {
                openedSharedReport = OpenedSharedReport(report: report, photo: photo)
            }
        } label: {
            HStack(spacing: 14) {
                if let thumbnail = resultsViewModel.thumbnail(for: report) {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: report.kind == .pdf ? "doc.richtext" : "photo")
                        .font(.title2)
                        .frame(width: 56, height: 56)
                        .tileSecondary()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Report shared \(report.receivedOn.formatted(date: .abbreviated, time: .shortened))")
                        .font(.headline)
                    Text("Tap to record a result from it")
                        .font(.subheadline)
                        .tileSecondary()
                }
                Spacer()
                Button {
                    resultsViewModel.dismissSharedReport(report)
                } label: {
                    Image(systemName: "trash")
                        .font(.footnote)
                        .foregroundStyle(AppColours.warning)
                        .padding(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete this shared report")
            }
        }
        .buttonStyle(.plain)
    }

    /// Shows the open error only while a sheet isn't up, and clears it after the update.
    private var sharedReportErrorBinding: Binding<Bool> {
        Binding(
            get: { resultsViewModel.errorMessage != nil && openedSharedReport == nil && !isPreparingQuestions },
            set: { isShowing in
                guard !isShowing else { return }
                DispatchQueue.main.async { resultsViewModel.errorMessage = nil }
            }
        )
    }
}

#Preview {
    let repository = InMemoryHealthRecordRepository()
    return HomeView(
        resultsViewModel: ResultsViewModel(repository: repository),
        followUpsViewModel: FollowUpsViewModel(repository: repository)
    )
}
