//
//  ResultsViewModelSharedReportTests.swift
//  YouTests
//

import Foundation
import Testing
import UIKit
@testable import You

/// An inbox that only remembers what it holds, no files involved.
private final class FakeInbox: ReportInboxing {
    var reports: [SharedReport]

    init(reports: [SharedReport]) {
        self.reports = reports
    }

    func receive(_ data: Data, kind: SharedReport.Kind) throws -> SharedReport {
        let report = SharedReport(id: UUID().uuidString, kind: kind, receivedOn: Date(), fileURL: URL(fileURLWithPath: "/dev/null"))
        reports.append(report)
        return report
    }

    func waiting() -> [SharedReport] { reports }

    func remove(_ report: SharedReport) {
        reports.removeAll { $0.id == report.id }
    }
}

/// Tests for how `ResultsViewModel` deals with reports shared into the inbox.
@MainActor
struct ResultsViewModelSharedReportTests {

    private let shared = SharedReport(id: "report.jpg", kind: .image, receivedOn: Date(), fileURL: URL(fileURLWithPath: "/dev/null"))

    private func makeViewModel() -> (ResultsViewModel, FakeInbox) {
        let inbox = FakeInbox(reports: [shared])
        let viewModel = ResultsViewModel(
            repository: InMemoryHealthRecordRepository(results: [], referrals: [], followUpTasks: []),
            inbox: inbox
        )
        return (viewModel, inbox)
    }

    @Test func test_sharedReports_listWhatIsWaiting_onLoad() {
        let (viewModel, _) = makeViewModel()

        #expect(viewModel.sharedReports.map(\.id) == ["report.jpg"])
    }

    @Test func test_record_removesSharedReport_fromInbox_whenSaved() {
        let (viewModel, inbox) = makeViewModel()

        let saved = viewModel.record(
            markerName: "Ferritin", valueText: "9", unit: "µg/L",
            rangeLowText: "30", rangeHighText: "300",
            collectedOn: Date(), orderingClinician: "Dr Michael",
            fromSharedReport: shared
        )

        #expect(saved)
        #expect(inbox.reports.isEmpty)
        #expect(viewModel.sharedReports.isEmpty)
    }

    @Test func test_record_keepsSharedReport_inInbox_whenEntryIsRefused() {
        let (viewModel, inbox) = makeViewModel()

        // 4000 is refused as a typo, so the report must still be waiting for another go.
        let saved = viewModel.record(
            markerName: "Ferritin", valueText: "4000", unit: "µg/L",
            rangeLowText: "30", rangeHighText: "300",
            collectedOn: Date(), orderingClinician: "Dr Michael",
            fromSharedReport: shared
        )

        #expect(!saved)
        #expect(inbox.reports.count == 1)
    }

    @Test func test_dismissSharedReport_removesIt_whenPatientSaysItIsNotAReport() {
        let (viewModel, inbox) = makeViewModel()

        viewModel.dismissSharedReport(shared)

        #expect(inbox.reports.isEmpty)
        #expect(viewModel.sharedReports.isEmpty)
    }
}
