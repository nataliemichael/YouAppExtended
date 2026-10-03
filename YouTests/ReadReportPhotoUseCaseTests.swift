//
//  ReadReportPhotoUseCaseTests.swift
//  YouTests
//

import Foundation
import Testing
@testable import You

/// Tests for `ReadReportPhotoUseCase`, the rules for lifting one marker's value
/// and healthy range out of the text read from a report photo. Each test feeds
/// fixed lines of text, so no camera is involved.
struct ReadReportPhotoUseCaseTests {

    private let useCase = ReadReportPhotoUseCase()

    private func marker(_ name: String) -> KnownMarker {
        KnownMarker.matching(name)!
    }

    // MARK: - Happy paths

    @Test func test_readReport_readsValueAndRange_fromTheMarkersLine() throws {
        let lines = [
            "Sana Yousefi   DOB 12/03/2004",
            "Collected 01/09/2026",
            "Ferritin   9 L   µg/L   (30-300)",
            "Haemoglobin   138   g/L   (115-165)"
        ]

        let read = try useCase.execute(marker: marker("Ferritin"), recognisedLines: lines)

        #expect(read.valueText == "9")
        #expect(read.rangeLowText == "30")
        #expect(read.rangeHighText == "300")
        #expect(read.sourceText.hasPrefix("Ferritin"))
    }

    @Test func test_readReport_readsEnDashRange_sameAsHyphen() throws {
        let read = try useCase.execute(
            marker: marker("Ferritin"),
            recognisedLines: ["Ferritin 9 µg/L 30 – 300"]
        )

        #expect(read.rangeLowText == "30")
        #expect(read.rangeHighText == "300")
    }

    @Test func test_readReport_keepsDecimals_forThyroidResult() throws {
        let read = try useCase.execute(
            marker: marker("TSH"),
            recognisedLines: ["TSH 2.1 mIU/L (0.5-4.0)"]
        )

        #expect(read.valueText == "2.1")
        #expect(read.rangeLowText == "0.5")
        #expect(read.rangeHighText == "4.0")
    }

    @Test func test_readReport_findsMarker_byTheLabsShortName() throws {
        // Labs print "Hb" for haemoglobin, the patient picks Haemoglobin from the list.
        let read = try useCase.execute(
            marker: marker("Haemoglobin"),
            recognisedLines: ["Hb 138 g/L (115-165)"]
        )

        #expect(read.valueText == "138")
    }

    @Test func test_readReport_takesRange_fromTheLineBeneath() throws {
        let read = try useCase.execute(
            marker: marker("Ferritin"),
            recognisedLines: ["Ferritin 9 µg/L", "(30-300)"]
        )

        #expect(read.valueText == "9")
        #expect(read.hasRange)
        #expect(read.rangeHighText == "300")
    }

    // MARK: - Boundaries

    @Test func test_readReport_doesNotMistakeLDL_forTotalCholesterol() throws {
        // "Cholesterol" is printed on both lines. The LDL line names LDL more
        // specifically, so total cholesterol must come from the second line.
        let lines = [
            "LDL cholesterol 3.1 mmol/L (<3.4)",
            "Cholesterol 5.2 mmol/L (3.9-5.5)"
        ]

        let read = try useCase.execute(marker: marker("Total cholesterol"), recognisedLines: lines)

        #expect(read.valueText == "5.2")
        #expect(read.rangeLowText == "3.9")
    }

    @Test func test_readReport_ignoresDigitsInsideTheUnit() throws {
        // x10^9/L is a unit, not three numbers.
        let read = try useCase.execute(
            marker: marker("Platelets"),
            recognisedLines: ["Platelets 250 x10^9/L (150-400)"]
        )

        #expect(read.valueText == "250")
        #expect(read.rangeLowText == "150")
        #expect(read.rangeHighText == "400")
    }

    @Test func test_readReport_leavesRangeEmpty_whenReportPrintsOnlyAnUpperLimit() throws {
        // "<3.4" is one number, not a low and a high, so the patient fills the range in.
        let read = try useCase.execute(
            marker: marker("LDL cholesterol"),
            recognisedLines: ["LDL cholesterol 3.1 mmol/L (<3.4)"]
        )

        #expect(read.valueText == "3.1")
        #expect(!read.hasRange)
    }

    @Test func test_readReport_skipsSectionHeading_andReadsTheResultLine() throws {
        // "Iron" appears in the heading with no number; the result is further down.
        let lines = ["Iron studies", "Iron 8 µmol/L (10-30)"]

        let read = try useCase.execute(marker: marker("Iron"), recognisedLines: lines)

        #expect(read.valueText == "8")
    }

    // MARK: - Domain errors

    @Test func test_readReport_fails_whenPhotoHasNoText() {
        #expect(throws: ReadReportPhotoError.noReadableText) {
            try useCase.execute(marker: marker("Ferritin"), recognisedLines: ["", "   "])
        }
    }

    @Test func test_readReport_fails_whenMarkerIsNotOnThePage() {
        #expect(throws: ReadReportPhotoError.markerNotFound(markerName: "Ferritin")) {
            try useCase.execute(
                marker: marker("Ferritin"),
                recognisedLines: ["Haemoglobin 138 g/L (115-165)", "TSH 2.1 mIU/L (0.5-4.0)"]
            )
        }
    }

    @Test func test_readReport_fails_whenMarkerLineHasNoNumber() {
        #expect(throws: ReadReportPhotoError.valueNotReadable(markerName: "Ferritin")) {
            try useCase.execute(
                marker: marker("Ferritin"),
                recognisedLines: ["Ferritin   see comment below"]
            )
        }
    }
}
