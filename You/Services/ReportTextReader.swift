//
//  ReportTextReader.swift
//  You
//

import UIKit
import Vision
import ImageIO

/// Anything that can turn a photo of a report into its printed lines, top to bottom.
/// The ViewModel only knows this protocol, so tests can hand it fixed lines and the
/// real reader can be swapped without touching a screen.
protocol ReportTextReading {
    func lines(in photo: UIImage) async throws -> [String]
}

/// Reads printed text with Apple's Vision framework. Everything runs on the
/// device, so the report never leaves the patient's phone.
nonisolated struct VisionReportTextReader: ReportTextReading {

    func lines(in photo: UIImage) async throws -> [String] {
        guard let image = photo.cgImage else { return [] }

        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false  // "9 L" must stay "9 L", not be corrected into a word

        let observations = try await request.perform(on: image, orientation: Self.orientation(of: photo))
        return observations
            .sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }  // Vision's y runs upwards, so this is top first
            .compactMap { $0.topCandidates(1).first?.string }
    }

    /// Vision needs to know which way up the photo was taken.
    private static func orientation(of photo: UIImage) -> CGImagePropertyOrientation {
        switch photo.imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
