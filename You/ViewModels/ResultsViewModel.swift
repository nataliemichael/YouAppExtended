//
//  ResultsViewModel.swift
//  You
//

import Foundation
import Combine
import UIKit

/// Connects the results screens to the record store and the recording use case.
/// Screens read `results` and `sharedReports`, ask `record(...)` to save, ask
/// `readReport(...)` to lift a value off a photo, ask `openSharedReport(...)` to
/// turn an inbox item into a photo, ask `reportPhoto(for:)` to show the photo a
/// result came from, and show `errorMessage` when something is refused.
@MainActor
final class ResultsViewModel: ObservableObject {
    @Published private(set) var results: [PathologyResult] = []
    /// Reports other apps shared into You that the patient hasn't dealt with yet, newest first.
    @Published private(set) var sharedReports: [SharedReport] = []
    @Published var errorMessage: String?

    private let repository: HealthRecordRepository
    private let recordResult: RecordPathologyResultUseCase
    private let readReportPhoto = ReadReportPhotoUseCase()
    private let openShared: OpenSharedReportUseCase
    private let textReader: ReportTextReading
    private let photoStore: ReportPhotoStoring
    private let inbox: ReportInboxing

    /// The app passes the Vision reader, the App Group photo folder, the App Group
    /// inbox and the PDF renderer. Tests pass fakes for each.
    init(
        repository: HealthRecordRepository,
        textReader: ReportTextReading = VisionReportTextReader(),
        photoStore: ReportPhotoStoring = ReportPhotoStore(),
        inbox: ReportInboxing = ReportInbox(),
        renderer: ReportFileRendering = ReportFileRenderer()
    ) {
        self.repository = repository
        self.recordResult = RecordPathologyResultUseCase(repository: repository)
        self.openShared = OpenSharedReportUseCase(renderer: renderer)
        self.textReader = textReader
        self.photoStore = photoStore
        self.inbox = inbox
        load()
    }

    /// Re-reads the store, newest report first, and whatever is waiting in the inbox.
    func load() {
        results = repository.results.sorted { $0.collectedOn > $1.collectedOn }
        sharedReports = inbox.waiting()
    }

    /// Records one marker from the entry form, keeping the report photo it was read
    /// from when there is one. Returns true when saved, false when refused, in which
    /// case `errorMessage` explains why in the patient's words and no photo is kept.
    func record(
        markerName: String,
        valueText: String,
        unit: String,
        rangeLowText: String,
        rangeHighText: String,
        collectedOn: Date,
        orderingClinician: String,
        reportPhoto: UIImage? = nil,
        fromSharedReport sharedReport: SharedReport? = nil
    ) -> Bool {
        guard let value = Double(valueText),
              let low = Double(rangeLowText),
              let high = Double(rangeHighText) else {
            errorMessage = "The value and healthy range need to be numbers, like 9 or 30. Check what you've typed against your report."
            return false
        }

        let photoFileName = reportPhoto?
            .jpegData(compressionQuality: 0.8)
            .flatMap { try? photoStore.save($0) }

        do {
            try recordResult.execute(
                markerName: markerName.trimmingCharacters(in: .whitespaces),
                value: value,
                unit: unit.trimmingCharacters(in: .whitespaces),
                referenceRange: ReferenceRange(lowerBound: low, upperBound: high),
                collectedOn: collectedOn,
                orderingClinician: orderingClinician.trimmingCharacters(in: .whitespaces),
                reportPhotoFileName: photoFileName
            )
            if let sharedReport {
                inbox.remove(sharedReport)  // dealt with, it leaves the inbox
            }
            load()
            return true
        } catch {
            if let photoFileName {
                photoStore.remove(fileName: photoFileName)  // a refused entry leaves nothing behind
            }
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Turns an inbox item into a photo the reader can work on. Returns nil when
    /// it can't, with `errorMessage` saying why in the patient's words.
    func openSharedReport(_ report: SharedReport) -> UIImage? {
        do {
            return try openShared.execute(report)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// A small picture of an inbox item for the Home list, or nil if it can't be drawn.
    func thumbnail(for report: SharedReport) -> UIImage? {
        (try? openShared.execute(report))?.preparingThumbnail(of: CGSize(width: 160, height: 160))
    }

    /// The patient says this isn't a report, or doesn't want it. It leaves the inbox.
    func dismissSharedReport(_ report: SharedReport) {
        inbox.remove(report)
        load()
    }

    /// The photo of the paper report a result was read from, or nil if it was typed in.
    func reportPhoto(for result: PathologyResult) -> UIImage? {
        guard let fileName = result.reportPhotoFileName,
              let data = photoStore.load(fileName: fileName) else { return nil }
        return UIImage(data: data)
    }

    /// Reads one marker's value and healthy range off a photo of the report.
    /// Returns what was read, or nil when it couldn't, in which case `errorMessage`
    /// says why in the patient's words. Nothing is saved, the form fills in and the
    /// patient still confirms against the paper.
    func readReport(for marker: KnownMarker, from photo: UIImage) async -> ReportLine? {
        do {
            let lines = try await textReader.lines(in: photo)
            return try readReportPhoto.execute(marker: marker, recognisedLines: lines)
        } catch let error as ReadReportPhotoError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "We couldn't read that photo. Try another one, or type the result in from the paper."
        }
        return nil
    }
}
