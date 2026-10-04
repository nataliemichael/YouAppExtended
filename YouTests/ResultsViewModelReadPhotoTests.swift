//
//  ResultsViewModelReadPhotoTests.swift
//  YouTests
//

import Foundation
import Testing
import UIKit
@testable import You

/// A text reader that answers with fixed lines, so the ViewModel can be tested
/// without a camera or Vision.
private struct FixedTextReader: ReportTextReading {
    let fixedLines: [String]
    func lines(in photo: UIImage) async throws -> [String] { fixedLines }
}

/// A text reader whose camera has failed, to check the patient still gets plain words.
private struct FailingTextReader: ReportTextReading {
    struct CameraFailed: Error {}
    func lines(in photo: UIImage) async throws -> [String] { throw CameraFailed() }
}

/// Tests for `ResultsViewModel.readReport`, the step between a photo and the form.
@MainActor
struct ResultsViewModelReadPhotoTests {

    private let ferritin = KnownMarker.matching("Ferritin")!

    private func makeViewModel(reading lines: [String]) -> ResultsViewModel {
        ResultsViewModel(
            repository: InMemoryHealthRecordRepository(results: [], referrals: [], followUpTasks: []),
            textReader: FixedTextReader(fixedLines: lines)
        )
    }

    @Test func test_readReport_returnsValueAndRange_whenMarkerIsOnThePhoto() async {
        let viewModel = makeViewModel(reading: ["Ferritin 9 L µg/L (30-300)"])

        let line = await viewModel.readReport(for: ferritin, from: UIImage())

        #expect(line?.valueText == "9")
        #expect(line?.rangeLowText == "30")
        #expect(line?.rangeHighText == "300")
        #expect(viewModel.errorMessage == nil)
    }

    @Test func test_readReport_explainsInPatientWords_whenMarkerIsNotOnThePhoto() async {
        let viewModel = makeViewModel(reading: ["Hb 138 g/L (115-165)"])

        let line = await viewModel.readReport(for: ferritin, from: UIImage())

        #expect(line == nil)
        #expect(viewModel.errorMessage == ReadReportPhotoError.markerNotFound(markerName: "Ferritin").errorDescription)
    }

    @Test func test_readReport_explainsInPatientWords_whenThePhotoCannotBeRead() async {
        let viewModel = ResultsViewModel(
            repository: InMemoryHealthRecordRepository(results: [], referrals: [], followUpTasks: []),
            textReader: FailingTextReader()
        )

        let line = await viewModel.readReport(for: ferritin, from: UIImage())

        #expect(line == nil)
        #expect(viewModel.errorMessage?.contains("couldn't read that photo") == true)
    }
}
