//
//  ReportInbox.swift
//  You
//

import Foundation

/// A report another app shared into You, waiting for the patient to record a
/// result from it. Either a photo or a PDF of the paper report.
struct SharedReport: Identifiable, Hashable {
    enum Kind: String {
        case image = "jpg"
        case pdf = "pdf"
    }

    /// The file name, unique per report.
    let id: String
    let kind: Kind
    let receivedOn: Date
    let fileURL: URL
}

/// Anything that can hold shared reports until the app deals with them. The share
/// extension puts reports in, the app lists and removes them. Tests use a temporary folder.
protocol ReportInboxing {
    /// Keeps a shared report and returns it.
    func receive(_ data: Data, kind: SharedReport.Kind) throws -> SharedReport
    /// Reports the patient has not dealt with yet, newest first.
    func waiting() -> [SharedReport]
    func remove(_ report: SharedReport)
}

/// The inbox folder inside the App Group container. The share extension writes
/// here and the app reads here, which is the only way the two can talk.
///
/// Business rules:
/// - A shared report is not a record. It waits in the inbox until the patient has
///   recorded a result from it or said it is not a report, then it is removed.
/// - Nothing is sent anywhere. The inbox is a folder on the patient's phone.
nonisolated final class ReportInbox: ReportInboxing {
    private let folder: URL

    /// The app and extension use the App Group inbox. Tests pass their own folder.
    init(folder: URL? = nil) {
        let base = AppGroup.containerURL
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.folder = folder ?? base.appendingPathComponent("Inbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.folder, withIntermediateDirectories: true)
    }

    func receive(_ data: Data, kind: SharedReport.Kind) throws -> SharedReport {
        let fileName = UUID().uuidString + "." + kind.rawValue
        let url = folder.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return SharedReport(id: fileName, kind: kind, receivedOn: Date(), fileURL: url)
    }

    func waiting() -> [SharedReport] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )) ?? []

        return urls
            .compactMap { url -> SharedReport? in
                guard let kind = SharedReport.Kind(rawValue: url.pathExtension.lowercased()) else { return nil }
                let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
                return SharedReport(id: url.lastPathComponent, kind: kind, receivedOn: created, fileURL: url)
            }
            .sorted { $0.receivedOn > $1.receivedOn }
    }

    func remove(_ report: SharedReport) {
        try? FileManager.default.removeItem(at: report.fileURL)
    }
}
