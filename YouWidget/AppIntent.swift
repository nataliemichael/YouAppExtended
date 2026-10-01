//
//  AppIntent.swift
//  YouWidget
//

import WidgetKit
import AppIntents

/// How far ahead the Coming up widget looks. A patient in a busy month wants
/// this week only; someone between check-ups wants the whole month.
enum LookAheadWindow: String, AppEnum {
    case week
    case fortnight
    case month

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Look ahead" }

    static var caseDisplayRepresentations: [LookAheadWindow: DisplayRepresentation] {
        [
            .week: "Next 7 days",
            .fortnight: "Next 14 days",
            .month: "Next 30 days"
        ]
    }

    /// The window in days, the unit the repository queries speak.
    var days: Int {
        switch self {
        case .week: return 7
        case .fortnight: return 14
        case .month: return 30
        }
    }
}

/// The one thing the patient can change on the widget: the window it looks ahead.
struct ComingUpConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Coming up" }
    static var description: IntentDescription { "Choose how far ahead to show referrals to use and follow-ups to do." }

    @Parameter(title: "Look ahead", default: .fortnight)
    var window: LookAheadWindow
}
