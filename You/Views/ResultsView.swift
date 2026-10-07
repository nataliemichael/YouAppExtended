//
//  ResultsView.swift
//  You
//

import SwiftUI
import Lottie

/// The patient's pathology results in one place: read past reports newest first
/// and add a new one. Reports shared in from other apps wait on Home.
struct ResultsView: View {
    @ObservedObject var viewModel: ResultsViewModel

    @State private var isAddingResult = false

    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // The brand heading, same shape as Home's "Hey / You."
                VStack(alignment: .leading, spacing: -4) {
                    Text("Here are your")
                        .font(BrandFonts.handwriting(size: 24))
                        .foregroundStyle(AppColours.ink)
                        .padding(.leading, 4)
                    Text("Results")
                        .brandTitle(size: 56)
                }
                .accessibilityElement(children: .combine)
                .padding(.horizontal, 20)

                // The add prompt sits on the sand under the heading, like the referral prompt on Follow-up.
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
                                .frame(width: 140, height: 62)
                        }
                        Text("Tap here to add a result from your report")  // runs the full width under both
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add a result")
                .padding(.horizontal, 20)
                .padding(.bottom, 10)  // the same breath Home leaves before its box

                TileBox {
                    SectionLabel(title: "Your results", systemImage: "list.bullet.clipboard")
                    if viewModel.results.isEmpty {
                        Text("No results yet. Add one from your report, or share a report into You from Mail or Photos.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.horizontal, 4)
                    }
                    ForEach(viewModel.results) { result in
                        resultTile(result)
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

    // MARK: - Tiles

    /// One report as its own tile: the date as the heading, what it says underneath.
    private func resultTile(_ result: PathologyResult) -> some View {
        NavigationLink(value: result) {
            Tile(title: result.collectedOn.formatted(date: .abbreviated, time: .omitted)) {
                HStack {
                    Text(summaryLine(for: result))
                        .font(.subheadline)
                        .foregroundStyle(result.flaggedMarkers.isEmpty ? Color.white.opacity(0.75) : AppColours.warningOnDark)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .tileSecondary()
                }
            }
        }
        .buttonStyle(.plain)
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
