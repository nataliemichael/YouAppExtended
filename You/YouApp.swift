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
    /// The JSON-backed store keeps records on the device between launches;
    /// swapping storage technology only ever changes this line.
    private let repository: HealthRecordRepository = JSONHealthRecordRepository()

    var body: some Scene {
        WindowGroup {
            RootView(repository: repository)
        }
    }
}
