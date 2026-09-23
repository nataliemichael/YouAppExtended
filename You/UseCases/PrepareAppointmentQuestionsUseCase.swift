//
//  PrepareAppointmentQuestionsUseCase.swift
//  You
//

import Foundation

/// The reasons question preparation can fail, each written for the patient with a way forward.
enum PrepareAppointmentQuestionsError: LocalizedError, Equatable {
    /// The appointment date has already passed.
    case appointmentDateInPast
    /// No results are outside their healthy range, so there is nothing to build questions from.
    case noFlaggedResultsToDiscuss
    /// Flagged results exist, but the newest is over a year old.
    case resultsOlderThanTwelveMonths

    var errorDescription: String? {
        switch self {
        case .appointmentDateInPast:
            return "That appointment date has already passed. Pick the date of your upcoming appointment."
        case .noFlaggedResultsToDiscuss:
            return "Good news, none of your recorded results are outside their healthy range, so there's nothing here to build questions from. You can still write your own notes for the GP."
        case .resultsOlderThanTwelveMonths:
            return "Your flagged results are more than a year old, so questions based on them could mislead your GP. Consider asking for a new test instead."
        }
    }
}

/// Turns the patient's flagged results into plain questions to ask at an upcoming
/// GP appointment.
///
/// The business operation: patients often leave appointments without asking about
/// the very results that worried them. Before a visit, the app collects every marker
/// currently outside its healthy range and writes one ready-to-read question for each,
/// so the conversation starts from the patient's own numbers.
///
/// Business rules, checked in order:
/// 1. The appointment must be today or later.
/// 2. Only results from the last twelve months count, older flagged results produce
///    a suggestion to re-test, not questions.
/// 3. One question per marker. When a marker was flagged on several reports, the
///    most recent reading speaks for it.
struct PrepareAppointmentQuestionsUseCase {
    let repository: HealthRecordRepository

    /// Flagged results older than this many months are considered too stale to ask about.
    static let maxResultAgeMonths = 12

    /// Builds the question list for the given appointment date.
    /// Throws a `PrepareAppointmentQuestionsError` naming the first rule that fails.
    func execute(appointmentOn: Date, today: Date = Date()) throws -> AppointmentPrep {
        let calendar = Calendar.current

        guard appointmentOn >= calendar.startOfDay(for: today) else {
            throw PrepareAppointmentQuestionsError.appointmentDateInPast
        }

        // Every flagged reading, paired with the date of the report it came from.
        let flaggedReadings: [(reading: MarkerReading, collectedOn: Date)] = repository.results
            .flatMap { result in
                result.flaggedMarkers.map { (reading: $0, collectedOn: result.collectedOn) }
            }

        guard !flaggedReadings.isEmpty else {
            throw PrepareAppointmentQuestionsError.noFlaggedResultsToDiscuss
        }

        let staleCutoff = calendar.date(
            byAdding: .month,
            value: -Self.maxResultAgeMonths,
            to: today
        ) ?? today
        let recentReadings = flaggedReadings.filter { $0.collectedOn >= staleCutoff }

        guard !recentReadings.isEmpty else {
            throw PrepareAppointmentQuestionsError.resultsOlderThanTwelveMonths
        }

        // One question per marker, the most recent reading speaks for it.
        var latestPerMarker: [String: (reading: MarkerReading, collectedOn: Date)] = [:]
        for entry in recentReadings {
            let key = entry.reading.markerName.lowercased()
            if let existing = latestPerMarker[key], existing.collectedOn >= entry.collectedOn {
                continue
            }
            latestPerMarker[key] = entry
        }

        let questions = latestPerMarker.values
            .sorted { $0.reading.markerName < $1.reading.markerName }
            .map { entry in
                AppointmentPrep.GPQuestion(
                    markerName: entry.reading.markerName,
                    question: questionText(for: entry.reading)
                )
            }

        return AppointmentPrep(appointmentOn: appointmentOn, questions: questions)
    }

    /// A ready-to-read question in the patient's voice.
    private func questionText(for reading: MarkerReading) -> String {
        let direction = reading.status == .belowRange ? "below" : "above"
        return "My \(reading.markerName) was \(reading.value.formatted()) \(reading.unit), which is \(direction) the healthy range. What should we do about it?"
    }
}
