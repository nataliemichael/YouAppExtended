//
//  ReferenceRangeBar.swift
//  You
//

import SwiftUI

/// Shows a marker value as a dot on a bar, with the lab's healthy range highlighted,
/// so the patient can see where they sit without reading numbers.
struct ReferenceRangeBar: View {
    let reading: MarkerReading

    /// The bar shows a little space either side of the healthy range so out-of-range dots have somewhere to land.
    private var displaySpan: (min: Double, max: Double) {
        let range = reading.referenceRange
        let padding = (range.upperBound - range.lowerBound) * 0.35
        return (range.lowerBound - padding, range.upperBound + padding)
    }

    /// Position of a value along the bar, clamped between 0 and 1.
    private func fraction(of value: Double) -> CGFloat {
        let span = displaySpan
        let raw = (value - span.min) / (span.max - span.min)
        return CGFloat(min(max(raw, 0), 1))
    }

    private var dotColour: Color {
        reading.isFlagged ? AppColours.coral : .green
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let rangeStart = fraction(of: reading.referenceRange.lowerBound) * width
            let rangeEnd = fraction(of: reading.referenceRange.upperBound) * width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray5))
                    .frame(height: 8)

                Capsule()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: rangeEnd - rangeStart, height: 8)
                    .offset(x: rangeStart)

                Circle()
                    .fill(dotColour)
                    .frame(width: 14, height: 14)
                    .offset(x: fraction(of: reading.value) * width - 7)
            }
            .frame(height: 14)
        }
        .frame(height: 14)
        .accessibilityLabel("\(reading.markerName) \(reading.value) \(reading.unit), \(reading.isFlagged ? "outside" : "within") the healthy range")
    }
}

#Preview {
    VStack(spacing: 24) {
        ReferenceRangeBar(reading: SampleData.lowFerritin)
        ReferenceRangeBar(reading: SampleData.haemoglobin)
    }
    .padding()
}
