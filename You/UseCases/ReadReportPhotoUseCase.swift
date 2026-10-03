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
///    healthy range.
/// 4. Table-style reports print the value and range in their own columns, which the
///    camera reads as separate lines beneath the marker's name. When the marker's
///    line has no number, the first line beneath holding a single number is the
///    value and the first holding a pair is the range. The search stops at the next
///    marker's line, or after a few lines, so numbers elsewhere on the page are
///    never picked up.
/// 5. Units are ignored even when they contain digits, like x10⁹/L, and so are long
///    numbers such as phone numbers and lab IDs, which are never results.
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

            let onLine = Self.numbers(in: String(line[printed.upperBound...]))
            let beneath = Self.columns(beneath: index, in: lines)

            var value = onLine.first
            var range: (low: String, high: String)? = nil
            if onLine.count >= 3 {
                range = (onLine[1], onLine[2])
            } else if onLine.isEmpty {
                value = beneath.value  // the value sits in its own column
                range = beneath.range
            } else if onLine.count == 1 {
                range = beneath.range  // value on the line, range printed under it
            }

            guard let value else { continue }  // a heading like "Iron studies", keep looking

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

    /// How many lines beneath a marker's name count as its columns.
    static let columnLookahead = 8

    /// A result is never this many digits long, so anything longer is a phone
    /// number, a date or a lab ID and is skipped.
    private static let longestResultLength = 7

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
        return numberPattern.matches(in: withoutUnits, range: whole)
            .compactMap { Range($0.range, in: withoutUnits).map { String(withoutUnits[$0]) } }
            .filter { $0.count <= longestResultLength }
    }

    /// The value and range printed in their own columns under a marker's name:
    /// the first line holding one number, and the first holding a pair. Stops at
    /// the next marker's line or after `columnLookahead` lines.
    private static func columns(beneath index: Int, in lines: [String]) -> (value: String?, range: (low: String, high: String)?) {
        var value: String?
        var range: (low: String, high: String)?
        for line in lines.dropFirst(index + 1).prefix(columnLookahead) {
            if KnownMarker.printed(on: line) != nil { break }
            let numbers = numbers(in: line)
            if numbers.count == 1, value == nil { value = numbers[0] }
            if numbers.count == 2, range == nil { range = (numbers[0], numbers[1]) }
            if value != nil, range != nil { break }
        }
        return (value, range)
    }
}
