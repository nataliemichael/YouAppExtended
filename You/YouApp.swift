//
//  YouApp.swift
//  You
//
//  Created by Natalie Michael on 31/8/2026.
//

import SwiftUI

@main
struct YouApp: App {
    /// The patient's one record store, shared by every screen.
    /// Core Data keeps records on the device between launches, in the App Group
    /// so the widget can read them; swapping storage technology only ever changes this line.
    private let repository: HealthRecordRepository = CoreDataHealthRecordRepository()

    init() {
        BrandFonts.register()  // the handwritten "Hey" on Home
    }

    var body: some Scene {
        WindowGroup {
            RootView(repository: repository)
        }
    }
}
