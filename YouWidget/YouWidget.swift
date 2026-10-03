//
//  YouWidget.swift
//  YouWidget
//

import WidgetKit
import SwiftUI

// MARK: - What the widget shows

/// One line on the patient's care schedule, ready to draw.
struct ScheduleLine: Identifiable {
    let id = UUID()
    let action: String
    let actBy: Date
    let daysLeft: Int

    /// Coral when it is due within three days or already overdue.
    var isUrgent: Bool { daysLeft <= 3 }

    var daysLeftText: String {
        switch daysLeft {
        case ..<0: return "overdue"
        case 0: return "today"
        case 1: return "tomorrow"
        default: return "\(daysLeft) days"
        }
    }
}

/// A snapshot of the schedule at one moment, the thing the timeline delivers.
struct ComingUpEntry: TimelineEntry {
    let date: Date
    let windowDays: Int
    let lines: [ScheduleLine]
    let flaggedCount: Int
}

// MARK: - Where it comes from

/// Reads the shared record store through the same repository the app uses.
/// The widget never opens Core Data itself, it asks the repository the same
/// question the Home screen asks.
struct ComingUpProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> ComingUpEntry {
        ComingUpEntry.sample
    }

    func snapshot(for configuration: ComingUpConfiguration, in context: Context) async -> ComingUpEntry {
        context.isPreview ? ComingUpEntry.sample : load(windowDays: configuration.window.days)
    }

    func timeline(for configuration: ComingUpConfiguration, in context: Context) async -> Timeline<ComingUpEntry> {
        let entry = load(windowDays: configuration.window.days)
        // Days-left counts change at midnight, and the app reloads the widget
        // itself after every save, so one refresh a day is enough.
        let tomorrow = Calendar.current.startOfDay(for: Date()).addingTimeInterval(24 * 60 * 60)
        return Timeline(entries: [entry], policy: .after(tomorrow))
    }

    private func load(windowDays: Int) -> ComingUpEntry {
        let repository = CoreDataHealthRecordRepository(seedsSampleRecords: false)
        let today = Date()
        let calendar = Calendar.current

        let lines = repository.careSchedule(withinDays: windowDays, on: today).map { item in
            ScheduleLine(
                action: item.patientAction,
                actBy: item.actBy,
                daysLeft: calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: today),
                    to: calendar.startOfDay(for: item.actBy)
                ).day ?? 0
            )
        }

        let twelveMonthsAgo = calendar.date(byAdding: .month, value: -12, to: today) ?? today
        let flagged = repository.flaggedReadings(since: twelveMonthsAgo).count

        return ComingUpEntry(date: today, windowDays: windowDays, lines: lines, flaggedCount: flagged)
    }
}

// MARK: - How it looks

struct ComingUpWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ComingUpEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            lockScreen
        case .systemMedium:
            medium
        default:
            small
        }
    }

    /// The single soonest thing, with its countdown as the hero.
    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            Spacer(minLength: 0)
            if let next = entry.lines.first {
                Text(next.daysLeftText)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(tint(for: next))
                    .minimumScaleFactor(0.7)
                Text(next.action)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            } else {
                nothingDue
            }
            Spacer(minLength: 0)
            flaggedLine
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// The next three things, each with its countdown badge, spread to fill the widget.
    private var medium: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                header
                Spacer()
                flaggedLine
            }
            .padding(.bottom, 6)

            if entry.lines.isEmpty {
                nothingDue
                Spacer(minLength: 0)
            }
            ForEach(entry.lines.prefix(3)) { line in
                HStack(spacing: 10) {
                    countdownBadge(for: line)
                    Text(line.action)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)  // long referral names wrap instead of cutting off
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity)  // rows share the height evenly
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Two lines readable without unlocking the phone.
    private var lockScreen: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let next = entry.lines.first {
                Text(next.action)
                    .font(.headline)
                    .lineLimit(2)
                Text("\(next.daysLeftText) · \(next.actBy.formatted(.dateTime.day().month(.abbreviated)))")
                    .font(.caption)
            } else {
                Text("You.")
                    .font(.headline)
                Text(nothingDueText)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Pieces

    private var header: some View {
        Label("Coming up", systemImage: "calendar")
            .font(.footnote)
            .fontWeight(.bold)
            .foregroundStyle(AppColours.ink)
    }

    /// "3 days" in a soft pill, coral when urgent.
    private func countdownBadge(for line: ScheduleLine) -> some View {
        Text(line.daysLeftText)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(tint(for: line))
            .frame(width: 66)
            .padding(.vertical, 5)
            .background(tint(for: line).opacity(0.15), in: Capsule())
    }

    @ViewBuilder
    private var flaggedLine: some View {
        if entry.flaggedCount > 0 {
            Label(
                entry.flaggedCount == 1 ? "1 result flagged" : "\(entry.flaggedCount) results flagged",
                systemImage: "exclamationmark.circle.fill"
            )
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(AppColours.warning)
        }
    }

    private var nothingDue: some View {
        Text(nothingDueText)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func tint(for line: ScheduleLine) -> Color {
        line.isUrgent ? AppColours.warning : AppColours.ink
    }

    private var nothingDueText: String {
        "Nothing due in the next \(entry.windowDays) days."
    }
}

// MARK: - The widget itself

struct ComingUpWidget: Widget {
    let kind: String = "ComingUpWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ComingUpConfiguration.self, provider: ComingUpProvider()) { entry in
            ComingUpWidgetView(entry: entry)
                .environment(\.colorScheme, .light)  // brand background is pale, keep text dark
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [AppColours.sandLight, AppColours.sand],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
        .configurationDisplayName("Coming up")
        .description("The next things in your care: referrals to use and follow-ups to do.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Previews

extension ComingUpEntry {
    /// Placeholder data for the widget gallery and previews.
    static var sample: ComingUpEntry {
        let today = Date()
        func days(_ n: Int) -> Date { Calendar.current.date(byAdding: .day, value: n, to: today) ?? today }
        return ComingUpEntry(
            date: today,
            windowDays: 14,
            lines: [
                ScheduleLine(action: "Book the iron studies blood test", actBy: days(3), daysLeft: 3),
                ScheduleLine(action: "Ask Dr Michael about low ferritin", actBy: days(7), daysLeft: 7),
                ScheduleLine(action: "Use your referral: Iron studies re-check", actBy: days(12), daysLeft: 12)
            ],
            flaggedCount: 1
        )
    }
}

#Preview("Small", as: .systemSmall) {
    ComingUpWidget()
} timeline: {
    ComingUpEntry.sample
}

#Preview("Medium", as: .systemMedium) {
    ComingUpWidget()
} timeline: {
    ComingUpEntry.sample
}

#Preview("Lock Screen", as: .accessoryRectangular) {
    ComingUpWidget()
} timeline: {
    ComingUpEntry.sample
}
