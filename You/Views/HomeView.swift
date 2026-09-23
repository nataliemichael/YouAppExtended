//
//  HomeView.swift
//  You
//

import SwiftUI
import Lottie

/// The first screen: a short "needs your attention" summary, then the patient's
/// pathology results newest first.
struct HomeView: View {
    @ObservedObject var resultsViewModel: ResultsViewModel
    @ObservedObject var followUpsViewModel: FollowUpsViewModel

    @State private var isAddingResult = false

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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 14) {
                            LottieView(animation: .named("Waving"))
                                .looping()
                                .frame(width: 116, height: 100)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(greeting)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text(patientFirstName.isEmpty
                                    ? "Tap here to tell us your name."
                                    : "Here's where your health is at today.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .onTapGesture {
                                nameDraft = patientFirstName
                                isEditingName = true
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 4, trailing: 20))
                }

                if !attentionMarkers.isEmpty || openTaskCount > 0 {
                    Section("Needs your attention") {
                        if let next = followUpsViewModel.mostUrgentAction {
                            Label {
                                Text("Next: \(next.patientAction), by \(next.actBy.formatted(date: .abbreviated, time: .omitted))")
                            } icon: {
                                Image(systemName: "arrow.forward.circle.fill")
                                    .foregroundStyle(AppColours.teal)
                            }
                        }
                        ForEach(attentionMarkers) { reading in
                            Label {
                                Text("\(reading.markerName) is outside the healthy range")
                            } icon: {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(AppColours.coral)
                            }
                        }
                        if openTaskCount > 0 {
                            Label {
                                Text(openTaskCount == 1
                                    ? "1 task waiting in Follow-ups"
                                    : "\(openTaskCount) tasks waiting in Follow-ups")
                            } icon: {
                                Image(systemName: "checklist")
                                    .foregroundStyle(AppColours.teal)
                            }
                        }
                    }
                }

                Section("Your results") {
                    ForEach(resultsViewModel.results) { result in
                        NavigationLink(value: result) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.collectedOn.formatted(date: .abbreviated, time: .omitted))
                                    .font(.headline)
                                Text(summaryLine(for: result))
                                    .font(.subheadline)
                                    .foregroundStyle(result.flaggedMarkers.isEmpty ? Color.secondary : AppColours.coral)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        isAddingResult = true
                    } label: {
                        HStack(spacing: 14) {
                            Text("Got a new blood test? Tap here to add a result from your report!")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                            LottieView(animation: .named("ECG"))
                                .looping()
                                .frame(width: 140, height: 67)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add a result")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 20))
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(AppColours.paleTeal)
            .contentMargins(.top, 0, for: .scrollContent)
            .navigationDestination(for: PathologyResult.self) { result in
                ResultDetailView(result: result)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("You.")
                        .font(.title)
                        .fontWeight(.bold)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .sheet(isPresented: $isAddingResult) {
                RecordResultView(viewModel: resultsViewModel)
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

    private func summaryLine(for result: PathologyResult) -> String {
        let flagged = result.flaggedMarkers
        if flagged.isEmpty {
            return "All \(result.markers.count) markers within healthy range"
        }
        let names = flagged.map(\.markerName).joined(separator: ", ")
        return "\(names) outside healthy range"
    }
}

#Preview {
    let repository = InMemoryHealthRecordRepository()
    return HomeView(
        resultsViewModel: ResultsViewModel(repository: repository),
        followUpsViewModel: FollowUpsViewModel(repository: repository)
    )
}
