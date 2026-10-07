//
//  AppColours.swift
//  You
//

import SwiftUI

/// The app's colours, matched to the You. pitch deck: warm sand paper, charcoal
/// ink and stone-grey line work. Named by job, not by hue, so a view says what
/// it means (a warning, a background) and the palette can change underneath.
///
/// Health status colours are kept separate on purpose: a flagged result should
/// never look like decoration.
enum AppColours {
    /// Every screen's background, the paper the app is drawn on.
    static let sand = Color(red: 0xE8 / 255, green: 0xE2 / 255, blue: 0xD8 / 255)

    /// A slightly lighter sand for cards and the widget's top edge.
    static let sandLight = Color(red: 0xF2 / 255, green: 0xEE / 255, blue: 0xE7 / 255)

    /// Headings, buttons, links and anything that should read as "the app's voice".
    static let ink = Color(red: 0x4A / 255, green: 0x46 / 255, blue: 0x3F / 255)

    /// Secondary text, outlines, dividers and the empty part of a range bar.
    static let stone = Color(red: 0xA9 / 255, green: 0xA1 / 255, blue: 0x96 / 255)

    /// Flagged results and due warnings. The one warm colour, used only when
    /// something needs the patient's attention.
    static let warning = Color(red: 0xC4 / 255, green: 0x66 / 255, blue: 0x4B / 255)

    /// The warning colour for text on the dark tiles, lifted so it stays readable.
    static let warningOnDark = Color(red: 0xEC / 255, green: 0xA8 / 255, blue: 0x92 / 255)

    /// Completed tasks and the healthy part of a range bar.
    static let done = Color(red: 0x7E / 255, green: 0x8F / 255, blue: 0x6E / 255)
}

extension View {
    /// The big condensed heading from the pitch deck, for screen titles like "You.".
    func brandTitle(size: CGFloat = 32) -> some View {
        self
            .font(.system(size: size, weight: .black))
            .fontWidth(.condensed)
            .textCase(.uppercase)
            .foregroundStyle(AppColours.ink)
    }
}
