//
//  Tiles.swift
//  You
//

import SwiftUI

/// The dark, thin rimmed box each tab stacks under its heading, holding a small
/// caps label and translucent tiles. The look is borrowed from the Weather app's
/// panels, in the app's own colours. The whole tab scrolls, the boxes do not.
struct TileBox<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(AppColours.ink.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
        )
    }
}

/// One translucent tile inside the container: a heading at the top, rows beneath.
/// Headings are the Weather app's bold style, or the handwriting for prompts.
struct Tile<Content: View>: View {
    let title: String
    var handwritten = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if handwritten {
                    Text(title)
                        .font(BrandFonts.handwriting(size: 26))
                } else {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }
            .foregroundStyle(.white)
            .padding(.bottom, 2)
            content
        }
        .foregroundStyle(.white)  // everything inside reads white on the dark tile
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}

/// The small caps label Weather puts at the top of a panel, e.g. "HOURLY FORECAST",
/// with one of Apple's symbols in front.
struct SectionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title.uppercased(), systemImage: systemImage)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 4)
            .padding(.top, 2)
    }
}

extension View {
    /// The translucent tile look on any layout, for tiles that need their own shape inside.
    func tileBackground() -> some View {
        self
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white.opacity(0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
            )
    }

    /// A row inside a tile, with a hairline under it except on the last one.
    func tileRow(last: Bool) -> some View {
        self
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                if !last { Rectangle().fill(Color.white.opacity(0.25)).frame(height: 1) }
            }
    }

    /// Softer white for second lines inside a tile.
    func tileSecondary() -> some View {
        self.foregroundStyle(.white.opacity(0.75))
    }
}
