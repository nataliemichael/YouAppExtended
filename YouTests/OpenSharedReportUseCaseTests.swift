//
//  OpenSharedReportUseCaseTests.swift
//  YouTests
//

import Foundation
import Testing
import UIKit
@testable import You

/// A renderer that answers with a fixed picture, or nothing, so no PDF is needed.
private struct FixedRenderer: ReportFileRendering {
    let image: UIImage?
    func image(from data: Data, kind: SharedReport.Kind) -> UIImage? { image }
}

/// Tests for `OpenSharedReportUseCase`, the rules for turning an inbox item into a
/// picture the reader can work on. Files live in a temporary folder.
struct OpenSharedReportUseCaseTests {

    private var samplePhoto: UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
    }

    private func report(withContents data: Data?, kind: SharedReport.Kind = .image) throws -> SharedReport {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(kind.rawValue)")
        if let data { try data.write(to: url) }
        return SharedReport(id: url.lastPathComponent, kind: kind, receivedOn: Date(), fileURL: url)
    }

    @Test func test_openSharedReport_returnsPicture_forSharedPhoto() throws {
        let useCase = OpenSharedReportUseCase(renderer: FixedRenderer(image: samplePhoto))
        let shared = try report(withContents: Data("photo bytes".utf8))

        let picture = try useCase.execute(shared)

        #expect(picture.size.width == 2)
    }

    @Test func test_openSharedReport_fails_whenFileHasGone() throws {
        let useCase = OpenSharedReportUseCase(renderer: FixedRenderer(image: samplePhoto))
        let missing = try report(withContents: nil)

        #expect(throws: OpenSharedReportError.couldNotOpen) {
            try useCase.execute(missing)
        }
    }

    @Test func test_openSharedReport_fails_whenFileIsNotAReport() throws {
        // Something was shared but it can't be drawn as a photo or PDF page.
        let useCase = OpenSharedReportUseCase(renderer: FixedRenderer(image: nil))
        let junk = try report(withContents: Data("not an image".utf8), kind: .pdf)

        #expect(throws: OpenSharedReportError.notAReport) {
            try useCase.execute(junk)
        }
    }
}
