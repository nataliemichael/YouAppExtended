//
//  RootView.swift
//  You
//

import SwiftUI

/// The app's two main areas: understanding results (Home) and acting on them (Follow-ups).
/// Both tabs share the one record store through their ViewModels.
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
