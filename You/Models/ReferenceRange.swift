//
//  ReferenceRange.swift
//  You
//

import Foundation

/// The healthy interval a pathology lab prints beside a marker, e.g. ferritin 30–300 
///
/// Business rule: a value counts as in range when it sits on or between both bounds.
/// Labs treat a value exactly on a bound as within range, so both bounds are inclusive.
struct ReferenceRange: Codable, Hashable {
    /// The lowest healthy value, inclusive.
    let lowerBound: Double

    /// The highest healthy value, inclusive.
    let upperBound: Double

    /// Where a measured value sits relative to the healthy range.
    enum Status: String, Codable {
        case belowRange
        case inRange
        case aboveRange
    }

    /// Classifies a measured value against this range.
    func status(for value: Double) -> Status {
        if value < lowerBound { return .belowRange }
        if value > upperBound { return .aboveRange }
        return .inRange
    }
}
