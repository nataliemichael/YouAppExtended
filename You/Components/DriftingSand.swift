//
//  DriftingSand.swift
//  You
//

import SwiftUI

/// The app's sand background, slowly moving like the sky behind the Weather app,
/// in the app's own colours. A few large, soft, blurred shapes of lighter and
/// deeper sand drift across the page like slow cloud shadows, each on its own
/// path and speed. Nothing has an edge, so the records on top stay readable.
/// Sits behind every tab.
struct DriftingSand: View {
    private let warm = Color(red: 0xF6 / 255, green: 0xEC / 255, blue: 0xDC / 255)   // lighter, a little peach
    private let shade = Color(red: 0xD3 / 255, green: 0xC9 / 255, blue: 0xBA / 255)  // deeper, towards stone

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geometry in
                let w = geometry.size.width, h = geometry.size.height
                ZStack {
                    AppColours.sand
                    cloud(warm, size: w * 0.9, x: w * (0.5 + 0.35 * sin(t / 11)), y: h * (0.25 + 0.15 * cos(t / 13)))
                    cloud(shade, size: w * 0.8, x: w * (0.5 + 0.4 * cos(t / 15)), y: h * (0.65 + 0.2 * sin(t / 10)))
                    cloud(warm, size: w * 0.6, x: w * (0.5 - 0.4 * sin(t / 9)), y: h * (0.85 + 0.1 * cos(t / 12)))
                    cloud(shade, size: w * 0.5, x: w * (0.5 + 0.3 * cos(t / 8)), y: h * (0.1 + 0.1 * sin(t / 14)))
                }
                .blur(radius: 60)  // keeps every shape soft
            }
        }
        .ignoresSafeArea()
    }

    private func cloud(_ colour: Color, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(colour)
            .frame(width: size, height: size)
            .position(x: x, y: y)
    }
}

#Preview {
    DriftingSand()
}
