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

    private var openTaskCount: Int {
        followUpsViewModel.openTasks.count
    }

    private var hasSomethingToShow: Bool {
        !attentionMarkers.isEmpty || openTaskCount > 0
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
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
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 4, trailing: 20))
                }

                Section {
                    if !hasSomethingToShow {
                        Text("Nothing needs doing right now. Your results and follow-ups are in the tabs below.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let next = followUpsViewModel.mostUrgentAction {
                        Label {
                            Text("Next: \(next.patientAction), by \(next.actBy.formatted(date: .abbreviated, time: .omitted))")
                        } icon: {
                            Image(systemName: "arrow.forward.circle.fill")
                                .foregroundStyle(AppColours.ink)
                        }
                    }
                    ForEach(attentionMarkers) { reading in
                        Label {
                            Text("\(reading.markerName) is outside the healthy range")
                        } icon: {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(AppColours.warning)
                        }
                    }
                    if openTaskCount > 0 {
                        Label {
                            Text(openTaskCount == 1
                                ? "1 task waiting in Follow-ups"
                                : "\(openTaskCount) tasks waiting in Follow-ups")
                        } icon: {
                            Image(systemName: "checklist")
                                .foregroundStyle(AppColours.ink)
                        }
                    }
                } header: {
                    Text("Needs your attention").handwrittenHeading()
                }

                if !resultsViewModel.sharedReports.isEmpty {
                    Section {
                        ForEach(resultsViewModel.sharedReports) { report in
                            sharedReportRow(report)
                        }
                    } header: {
                        Text("Shared to You").handwrittenHeading()
                    }
                }

                Section {
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
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(AppColours.sand)
            .contentMargins(.top, 0, for: .scrollContent)
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
                        .foregroundStyle(AppColours.stone)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Report shared \(report.receivedOn.formatted(date: .abbreviated, time: .shortened))")
                        .font(.headline)
                    Text("Tap to record a result from it")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .swipeActions {
            Button("Delete", systemImage: "trash", role: .destructive) {
                resultsViewModel.dismissSharedReport(report)
            }
            .tint(AppColours.warning)  // the app's own warning colour, not the system red
        }
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
