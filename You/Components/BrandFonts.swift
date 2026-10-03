//
//  BrandFonts.swift
//  You
//

import SwiftUI
import CoreText

/// The one custom typeface the app ships: "Nothing You Could Do" by Kimberly
/// Geswein, used for the handwritten "Hey" on the Home screen. Licensed under
/// the SIL Open Font License (see Resources/Fonts/NothingYouCouldDo-OFL.txt).
///
/// The font is registered at launch rather than listed in Info.plist, so the
/// project's generated Info.plist stays untouched.
enum BrandFonts {
    static let handwritingName = "NothingYouCouldDo"

    /// Call once at launch. Safe to call again, re-registering is a no-op.
    static func register() {
        guard let url = Bundle.main.url(forResource: handwritingName, withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    /// The handwritten face at a given size, falling back to the system font
    /// if the file ever goes missing so the screen still renders.
    static func handwriting(size: CGFloat) -> Font {
        .custom(handwritingName, size: size)
    }
}
