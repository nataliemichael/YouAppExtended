//
//  ResultsView.swift
//  You
//

import SwiftUI
import Lottie

/// The patient's pathology results in one place: add a new one and read past
/// reports newest first. Reports shared in from other apps wait on Home.
struct ResultsView: View {
    @ObservedObject var viewModel: ResultsViewModel

    @State private var isAddingResult = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // The brand heading with the searching figure beside it, same shape as Home.
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: -4) {
                            Text("Here are your")
                                .font(BrandFonts.handwriting(size: 24))
                                .foregroundStyle(AppColours.ink)
                                .padding(.leading, 4)
                            Text("Results")
                                .brandTitle(size: 56)
                        }
                        .accessibilityElement(children: .combine)
                        LottieView(animation: .named("Search"))
                            .looping()
                            .frame(width: 130, height: 112)
                        Spacer(minLength: 0)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 4, trailing: 20))
                }

                Section {
                    if viewModel.results.isEmpty {
                        Text("No results yet. Add one from your report, or share a report into You from Mail or Photos.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.results) { result in
                        NavigationLink(value: result) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.collectedOn.formatted(date: .abbreviated, time: .omitted))
                                    .font(.headline)
                                Text(summaryLine(for: result))
                                    .font(.subheadline)
                                    .foregroundStyle(result.flaggedMarkers.isEmpty ? Color.secondary : AppColours.warning)
                            }
                        }
                    }
                } header: {
                    Text("Your results").handwrittenHeading()
                }

                Section {
                    Button {
                        isAddingResult = true
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .top, spacing: 10) {
                                Text("Got a new blood test?")
                                    .handwrittenHeading(size: 26)
                                    .multilineTextAlignment(.leading)
                                LottieView(animation: .named("ECG"))
                                    .looping()
                                    .frame(width: 140, height: 66)  // the heartbeat is wide and short, a tall frame leaves a gap
                            }
                            Text("Tap here to add a result from your report")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add a result")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(AppColours.sand)
            .contentMargins(.top, 0, for: .scrollContent)
            .navigationDestination(for: PathologyResult.self) { result in
                ResultDetailView(result: result, reportPhoto: viewModel.reportPhoto(for: result))
            }
            .sheet(isPresented: $isAddingResult) {
                RecordResultView(viewModel: viewModel)
            }
            .onAppear {
                viewModel.load()
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
    ResultsView(viewModel: ResultsViewModel(repository: InMemoryHealthRecordRepository()))
}
