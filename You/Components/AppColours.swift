//
//  AppColours.swift
//  You
//

import SwiftUI

/// The app's colours, matched to the You. brand animation.
/// Health status colours (orange flagged, red expired, green done) are kept
/// separate on purpose, a flagged result should never look like decoration.
enum AppColours {
    /// Brand teal
    static let teal = Color(red: 0x3C / 255, green: 0xAE / 255, blue: 0xBD / 255)

    /// Soft highlight
    static let mint = Color(red: 0xC6 / 255, green: 0xE6 / 255, blue: 0xDF / 255)

    /// Background colour
    static let paleTeal = Color(red: 0xE9 / 255, green: 0xF6 / 255, blue: 0xF7 / 255)

    /// Flagged results and due warnings
    static let coral = Color(red: 0xE8 / 255, green: 0x5D / 255, blue: 0x75 / 255)
}
