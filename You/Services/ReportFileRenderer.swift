//
//  ReportFileRenderer.swift
//  You
//

import UIKit
import PDFKit

/// Anything that can turn a shared report file into a picture the text reader can
/// work on. The ViewModel only knows this protocol, so tests hand it a fake.
protocol ReportFileRendering {
    func image(from data: Data, kind: SharedReport.Kind) -> UIImage?
}

/// Photos are used as they are. PDFs have their first page drawn at a size large
/// enough for the printed numbers to be read. Everything happens on the device.
nonisolated struct ReportFileRenderer: ReportFileRendering {

    /// Wide enough that a report's small print survives text recognition.
    static let pdfRenderWidth: CGFloat = 2000

    func image(from data: Data, kind: SharedReport.Kind) -> UIImage? {
        switch kind {
        case .image:
            return UIImage(data: data)
        case .pdf:
            guard let page = PDFDocument(data: data)?.page(at: 0) else { return nil }
            let bounds = page.bounds(for: .mediaBox)
            let scale = Self.pdfRenderWidth / max(bounds.width, 1)
            return page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
        }
    }
}
