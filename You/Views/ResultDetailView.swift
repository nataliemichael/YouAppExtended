//
//  ResultDetailView.swift
//  You
//

import SwiftUI

/// One pathology report in full: every marker with its healthy range and a plain-language explanation.
/// Flagged markers are listed first because they are what the patient came to understand.
struct ResultDetailView: View {
    let result: PathologyResult

    /// Flagged markers first, then the rest.
    private var orderedMarkers: [MarkerReading] {
        result.flaggedMarkers + result.markers.filter { !$0.isFlagged }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Collected", value: result.collectedOn.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Ordered by", value: result.orderingClinician)
            }

            ForEach(orderedMarkers) { reading in
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        Text(reading.markerName)
                            .font(.headline)
                        Spacer()
                        Text("\(reading.value.formatted()) \(reading.unit)")
                            .font(.headline)
                            .foregroundStyle(reading.isFlagged ? AppColours.coral : Color.primary)
                    }

                    ReferenceRangeBar(reading: reading)
                        .padding(.vertical, 4)

                    Text(statusLine(for: reading))
                        .font(.subheadline)
                        .foregroundStyle(reading.isFlagged ? AppColours.coral : Color.secondary)

                    Text(reading.plainLanguageExplanation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("This explains your results in plain language. It is not medical advice. Your GP is the right person to interpret what it means for you.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Your results")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppColours.paleTeal)
    }

    private func statusLine(for reading: MarkerReading) -> String {
        let range = reading.referenceRange
        switch reading.status {
        case .inRange:
            return "Within the healthy range (\(range.lowerBound.formatted())–\(range.upperBound.formatted()))"
        case .belowRange:
            return "Below the healthy range (\(range.lowerBound.formatted())–\(range.upperBound.formatted())), worth raising with your GP"
        case .aboveRange:
            return "Above the healthy range (\(range.lowerBound.formatted())–\(range.upperBound.formatted())), worth raising with your GP"
        }
    }
}

#Preview {
    NavigationStack {
        ResultDetailView(result: SampleData.results[0])
    }
}
