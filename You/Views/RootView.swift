//
//  RootView.swift
//  You
//

import SwiftUI

/// The app's three areas: what needs attention now (Home), understanding results
/// (Results) and acting on them (Follow-ups). All tabs share the one record store
/// through their ViewModels.
struct RootView: View {
    @StateObject private var resultsViewModel: ResultsViewModel
    @StateObject private var followUpsViewModel: FollowUpsViewModel

    init(repository: HealthRecordRepository) {
        _resultsViewModel = StateObject(wrappedValue: ResultsViewModel(repository: repository))
        _followUpsViewModel = StateObject(wrappedValue: FollowUpsViewModel(repository: repository))
    }

    var body: some View {
        TabView {
            HomeView(
                resultsViewModel: resultsViewModel,
                followUpsViewModel: followUpsViewModel
            )
            .tabItem {
                Label("Home", systemImage: "heart.text.square")
            }

            ResultsView(viewModel: resultsViewModel)
                .tabItem {
                    Label("Results", systemImage: "list.bullet.clipboard")
                }

            FollowUpsView(viewModel: followUpsViewModel)
                .tabItem {
                    Label("Follow-ups", systemImage: "checklist")
                }
        }
    }
}

#Preview {
    RootView(repository: InMemoryHealthRecordRepository())
}
