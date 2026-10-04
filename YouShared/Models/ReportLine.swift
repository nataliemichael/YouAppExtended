//
//  ReportLine.swift
//  You
//

import Foundation

/// One marker's line as read from a photo of the report, before the patient has
/// confirmed it. Everything is kept as text exactly as read, so the form can show
/// it for checking and the patient can fix a misread digit before saving.
///
/// Business rule: a read line is a draft, never a record. It only becomes a
/// `MarkerReading` once the patient confirms it against the paper.
struct ReportLine: Hashable {
    /// The measured value as printed, e.g. "9".
    let valueText: String

    /// The low end of the healthy range as printed, when the line had one.
    let rangeLowText: String?

    /// The high end of the healthy range as printed, when the line had one.
    let rangeHighText: String?

    /// The printed line the value came from, shown so the patient can see what was read.
    let sourceText: String

    var hasRange: Bool {
        rangeLowText != nil && rangeHighText != nil
    }
}
