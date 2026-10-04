//
//  OpenSharedReportUseCase.swift
//  You
//

import UIKit

/// The reasons a shared report can't be opened, each written for the patient with a way forward.
enum OpenSharedReportError: LocalizedError, Equatable {
    /// The file is gone or empty.
    case couldNotOpen
    /// The file opened but is not a photo or PDF the app can read.
    case notAReport

    var errorDescription: String? {
        switch self {
        case .couldNotOpen:
            return "We couldn't open that shared report, it may have been removed. Try sharing it into You again."
        case .notAReport:
            return "That file doesn't look like a photo or PDF of a report, so there's nothing to read from it. Remove it, or type your result in by hand."
        }
    }
}

/// Opens a report another app shared into You so the patient can record a result from it.
///
/// The business operation: a report arrives in the inbox from Mail, Messages or
/// Files. Before the patient can read a value off it, the app turns the file into
/// a picture, a photo as it is or a PDF's first page, that the same text reader
/// used by the camera can work on. One reader, two ways in.
///
/// Business rules, checked in order:
/// 1. The file must still be there and have content.
/// 2. It must be a photo or PDF the app can draw. Only the first page of a PDF is
///    used, lab reports put the results table there.
struct OpenSharedReportUseCase {
    let renderer: ReportFileRendering

    /// Returns the report as a picture ready for reading.
    /// Throws an `OpenSharedReportError` naming the first rule that fails.
    func execute(_ report: SharedReport) throws -> UIImage {
        guard let data = try? Data(contentsOf: report.fileURL), !data.isEmpty else {
            throw OpenSharedReportError.couldNotOpen
        }
        guard let image = renderer.image(from: data, kind: report.kind) else {
            throw OpenSharedReportError.notAReport
        }
        return image
    }
}
