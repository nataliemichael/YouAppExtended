//
//  ReadReportPhotoUseCase.swift
//  You
//

import Foundation

/// The reasons reading a report photo can fail, each written for the patient with a way forward.
enum ReadReportPhotoError: LocalizedError, Equatable {
    /// The photo had no words the camera could make out.
    case noReadableText
    /// The chosen marker is not printed anywhere on this page.
    case markerNotFound(markerName: String)
    /// The marker is on the page but its line has no number to read.
    case valueNotReadable(markerName: String)

    var errorDescription: String? {
        switch self {
        case .noReadableText:
            return "We couldn't read any words in that photo. Try again in good light with the report flat and the camera straight above it."
        case .markerNotFound(let markerName):
            return "We couldn't find \(markerName) in that photo. Check it's on this page of your report and try again, or type it in from the paper."
        case .valueNotReadable(let markerName):
            return "We found \(markerName) but couldn't make out its number. Try a closer photo of that line, or type the value in from the paper."
        }
    }
}

/// Reads one marker's value and healthy range off a photo of a paper report.
///
/// The business operation: the patient picks the marker they want to record, then
/// photographs the report instead of typing. The app finds that marker's line in
/// the text the camera read and lifts out the value and the healthy range. Nothing
/// is saved here, the result pre-fills the form and the patient still confirms it
/// against the paper, because only they can tell a 9 from a misread 0.
///
/// Business rules, checked in order:
/// 1. The photo must contain readable text.
/// 2. The marker, under its lab name or an alias, must be printed on the page as a
///    whole word. Longer matches win, so "LDL cholesterol" is never read as total
///    cholesterol.
/// 3. The first number after the marker's name is the value. The next two are the
///    healthy range. Labs sometimes print the range on the line beneath, so a bare
///    pair of numbers there counts too.
/// 4. Units are ignored even when they contain digits, like x10⁹/L.
struct ReadReportPhotoUseCase {

    /// Finds the marker on the page and returns what was printed beside it.
    /// Throws a `ReadReportPhotoError` naming the first rule that fails.
    func execute(marker: KnownMarker, recognisedLines: [String]) throws -> ReportLine {
        let lines = recognisedLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else {
            throw ReadReportPhotoError.noReadableText
        }

        var markerSeen = false
        for (index, line) in lines.enumerated() {
            guard KnownMarker.printed(on: line) == marker,
                  let printed = marker.printedRange(in: line) else { continue }
            markerSeen = true

            let numbers = Self.numbers(in: String(line[printed.upperBound...]))
            guard let value = numbers.first else { continue }  // a heading like "Iron studies", keep looking

            var range: (low: String, high: String)? = nil
            if numbers.count >= 3 {
                range = (numbers[1], numbers[2])
            } else if index + 1 < lines.count {
                range = Self.bareRange(on: lines[index + 1])
            }

            return ReportLine(
                valueText: value,
                rangeLowText: range?.low,
                rangeHighText: range?.high,
                sourceText: line
            )
        }

        throw markerSeen
            ? ReadReportPhotoError.valueNotReadable(markerName: marker.name)
            : ReadReportPhotoError.markerNotFound(markerName: marker.name)
    }

    // MARK: - Helpers

    private static let numberPattern = try! NSRegularExpression(pattern: #"\d+(?:\.\d+)?"#)

    /// Every number in the text, in order, with units dropped first so the 9 in
    /// x10⁹/L or the 1.73 in mL/min/1.73m² is never mistaken for a result.
    private static func numbers(in text: String) -> [String] {
        let withoutUnits = text
            .split(whereSeparator: \.isWhitespace)
            .filter { token in
                !token.contains("/")  // µg/L, mmol/L, mL/min/1.73m²
                    && !(token.first?.isLetter == true && token.contains(where: \.isNumber))  // x10⁹, B12
            }
            .joined(separator: " ")

        let whole = NSRange(withoutUnits.startIndex..., in: withoutUnits)
        return numberPattern.matches(in: withoutUnits, range: whole).compactMap {
            Range($0.range, in: withoutUnits).map { String(withoutUnits[$0]) }
        }
    }

    /// A line that is nothing but a healthy range, e.g. "(30-300)" printed under
    /// the marker. Lines that name another marker never count.
    private static func bareRange(on line: String) -> (low: String, high: String)? {
        guard KnownMarker.printed(on: line) == nil else { return nil }
        let numbers = numbers(in: line)
        guard numbers.count == 2 else { return nil }
        return (numbers[0], numbers[1])
    }
}
