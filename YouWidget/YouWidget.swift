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
    var isOverdue: Bool { daysLeft < 0 }

    var daysLeftText: String {
        switch daysLeft {
        case ..<0: return "Overdue"
        case 0: return "Today"
        case 1: return "Tomorrow"
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

/// Deliberately quiet: one number you can read from across the room, the thing it
/// belongs to, and nothing else competing with it.
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

    /// The soonest thing: its countdown large, its name underneath, the wordmark in the corner.
    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let next = entry.lines.first {
                countdown(for: next, size: 40)
                Text(next.action)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColours.ink)
                    .lineLimit(2)
                    .padding(.top, 4)
                Text(next.isOverdue
                    ? "was due \(next.actBy.formatted(.dateTime.day().month(.abbreviated)))"
                    : "by \(next.actBy.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))")
                    .font(.caption2)
                    .foregroundStyle(AppColours.stone)
                    .padding(.top, 2)
            } else {
                Text(nothingDueText)
                    .font(.footnote)
                    .foregroundStyle(AppColours.stone)
            }
            Spacer(minLength: 0)
            wordmark
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// The medium is the dark one, split down the middle: the fortnight calendar on
    /// the left, the soonest thing with its countdown on the right, all in white.
    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Coming up", systemImage: "bell")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.75))
                fortnightGrid
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                if let next = entry.lines.first {
                    countdown(for: next, size: 40,
                              colour: next.isUrgent ? AppColours.warningOnDark : .white,
                              unitColour: .white.opacity(0.75))
                    Text(next.action)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .padding(.top, 2)
                    Text(next.isOverdue
                        ? "was due \(next.actBy.formatted(.dateTime.day().month(.abbreviated)))"
                        : "by \(next.actBy.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 2)
                } else {
                    Text(nothingDueText)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// The fortnight as a little calendar: weekday letters, then this week's dots
    /// and next week's beneath, filled where something is due.
    private var fortnightGrid: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: entry.date)
        let dueDays = Dictionary(grouping: entry.lines) { calendar.startOfDay(for: $0.actBy) }
        return VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { offset in
                    let day = calendar.date(byAdding: .day, value: offset, to: today) ?? today
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 11, weight: offset == 0 ? .bold : .regular, design: .rounded))
                        .foregroundStyle(offset == 0 ? stripInk : stripInk.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<2, id: \.self) { week in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { column in
                        let offset = week * 7 + column
                        let day = calendar.date(byAdding: .day, value: offset, to: today) ?? today
                        let due = dueDays[day]
                        Circle()
                            .fill(due == nil ? stripInk.opacity(0.25) : (due!.contains { $0.isUrgent } ? stripUrgent : stripInk))
                            .frame(width: due == nil ? 6 : 12, height: due == nil ? 6 : 12)
                            .frame(maxWidth: .infinity)
                            .frame(height: 14)
                    }
                }
            }
        }
    }

    /// The strip's colours: white on the dark medium, ink on the sand small.
    private var stripInk: Color { family == .systemMedium ? .white : AppColours.ink }
    private var stripUrgent: Color { family == .systemMedium ? AppColours.warningOnDark : AppColours.warning }

    /// Readable without unlocking the phone: the countdown first, then the item.
    private var lockScreen: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let next = entry.lines.first {
                Text(next.daysLeft > 1 ? "\(next.daysLeft) days" : next.daysLeftText)
                    .font(.headline)
                    .fontWeight(.bold)
                Text(next.action)
                    .font(.caption)
                    .lineLimit(2)
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

    /// "3 days" with the number in the app's condensed heading lettering, coral when urgent.
    fileprivate func countdown(for line: ScheduleLine, size: CGFloat, colour: Color? = nil, unitColour: Color = AppColours.stone) -> some View {
        let number = colour ?? tint(for: line)
        // The heading lettering applied directly, so the colour passed in actually wins.
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            switch line.daysLeft {
            case ..<0, 0, 1:
                Text(line.daysLeftText)  // "Overdue", "Today", "Tomorrow"
                    .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
                    .foregroundStyle(number)
            default:
                Text("\(line.daysLeft)")
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .foregroundStyle(number)
                Text("days")
                    .font(.system(.footnote, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(unitColour)
            }
        }
        .minimumScaleFactor(0.7)
    }

    /// The app's name, small, so the widget is recognisably You.
    fileprivate var wordmark: some View {
        Text("You.")
            .brandTitle(size: 14)
            .foregroundStyle(AppColours.stone)
    }

    fileprivate func tint(for line: ScheduleLine) -> Color {
        line.isUrgent ? AppColours.warning : AppColours.ink
    }

    private var nothingDueText: String {
        "Nothing due in the next \(entry.windowDays) days."
    }
}

/// The background each size gets: the clouds still on the Home Screen sizes,
/// nothing on the Lock Screen (the system tints it).
struct WidgetBackdrop: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium: AppColours.ink.opacity(0.8)  // a shade lighter than the app's boxes
        case .accessoryRectangular, .accessoryCircular, .accessoryInline: Color.clear
        default: CloudsStill()
        }
    }
}

// MARK: - Style options, preview only until one is chosen

/// Option 4, "Clouds": the current layout on a still of the drifting sand background.
struct CloudsStill: View {
    private let warm = Color(red: 0xF6 / 255, green: 0xEC / 255, blue: 0xDC / 255)
    private let shade = Color(red: 0xD3 / 255, green: 0xC9 / 255, blue: 0xBA / 255)

    var body: some View {
        ZStack {
            AppColours.sand
            RadialGradient(colors: [warm, warm.opacity(0)], center: .init(x: 0.25, y: 0.2), startRadius: 0, endRadius: 150)
            RadialGradient(colors: [shade, shade.opacity(0)], center: .init(x: 0.85, y: 0.7), startRadius: 0, endRadius: 150)
            RadialGradient(colors: [warm, warm.opacity(0)], center: .init(x: 0.6, y: 1.0), startRadius: 0, endRadius: 110)
        }
    }
}

// MARK: - The widget itself

struct ComingUpWidget: Widget {
    let kind: String = "ComingUpWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ComingUpConfiguration.self, provider: ComingUpProvider()) { entry in
            ComingUpWidgetView(entry: entry)
                .environment(\.colorScheme, .light)
                .containerBackground(for: .widget) {
                    WidgetBackdrop()
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
