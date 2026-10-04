//
//  ReportInboxTests.swift
//  YouTests
//

import Foundation
import Testing
@testable import You

/// Tests for `ReportInbox`, the folder the share extension fills and the app
/// empties. Each test gets its own temporary folder, so nothing touches the
/// real App Group.
struct ReportInboxTests {

    private func makeInbox() -> ReportInbox {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("inbox-\(UUID().uuidString)", isDirectory: true)
        return ReportInbox(folder: folder)
    }

    @Test func test_inbox_listsSharedReport_afterItIsReceived() throws {
        let inbox = makeInbox()

        let report = try inbox.receive(Data("pdf bytes".utf8), kind: .pdf)

        let waiting = inbox.waiting()
        #expect(waiting.count == 1)
        #expect(waiting.first?.id == report.id)
        #expect(waiting.first?.kind == .pdf)
        #expect(FileManager.default.fileExists(atPath: report.fileURL.path))
    }

    @Test func test_inbox_listsNewestReportFirst() throws {
        let inbox = makeInbox()

        let older = try inbox.receive(Data("one".utf8), kind: .image)
        Thread.sleep(forTimeInterval: 0.05)  // file creation dates need a gap to differ
        let newer = try inbox.receive(Data("two".utf8), kind: .image)

        #expect(inbox.waiting().map(\.id) == [newer.id, older.id])
    }

    @Test func test_inbox_isEmpty_afterReportIsRemoved() throws {
        let inbox = makeInbox()
        let report = try inbox.receive(Data("photo".utf8), kind: .image)

        inbox.remove(report)

        #expect(inbox.waiting().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: report.fileURL.path))
    }

    @Test func test_inbox_ignoresFilesThatAreNotReports() throws {
        let inbox = makeInbox()
        let report = try inbox.receive(Data("photo".utf8), kind: .image)

        // Something else lands in the folder, it must not show up as a report.
        let stray = report.fileURL.deletingLastPathComponent().appendingPathComponent("notes.txt")
        try Data("hello".utf8).write(to: stray)

        #expect(inbox.waiting().map(\.id) == [report.id])
    }
}
