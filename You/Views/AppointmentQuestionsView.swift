//
//  AppointmentQuestionsView.swift
//  You
//

import SwiftUI

/// Gets the patient ready for a GP visit: pick the appointment day and the app
/// writes one plain question for each result outside its healthy range, so the
/// conversation starts from the patient's own numbers.
///
/// Each question carries the marker's history across every report, so the patient
/// can say "it has been dropping for three tests" rather than quoting one number.
/// They can add their own questions underneath. The whole list can be shared to
/// Notes or Messages, or added to the to do list as a task due on the appointment day.
/// The app's questions are written fresh from the current results and never stored.
struct AppointmentQuestionsView: View {
    @ObservedObject var viewModel: FollowUpsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var appointmentOn: Date = Date()
    @State private var prep: AppointmentPrep?
    @State private var ownQuestions: [String] = []
    @State private var newQuestion = ""
    @State private var addedToTasks = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Appointment on", selection: $appointmentOn, in: Date()..., displayedComponents: .date)
                    Button("Write my questions", systemImage: "text.badge.checkmark") {
                        prep = viewModel.prepareQuestions(appointmentOn: appointmentOn)
                        addedToTasks = false
                    }
                } header: {
                    Text("Your appointment")
                } footer: {
                    Text("Written from your results that are outside the healthy range. Your GP decides what they mean for you.")
                }

                if let prep {
                    Section {
                        ForEach(prep.questions) { question in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(question.markerName)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(AppColours.warning)
                                Text(question.question)
                                    .font(.body)
                                historyLine(for: question.markerName)
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text("Questions to ask").handwrittenHeading()
                    }

                    Section {
                        ForEach(ownQuestions, id: \.self) { question in
                            Text(question)
                        }
                        .onDelete { ownQuestions.remove(atOffsets: $0) }
                        HStack {
                            TextField("Anything else you want to ask?", text: $newQuestion)
                                .onSubmit(addOwnQuestion)
                            Button("Add", action: addOwnQuestion)
                                .disabled(newQuestion.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    } header: {
                        Text("Your own questions").handwrittenHeading()
                    } footer: {
                        Text("Anything that's been on your mind. Swipe left on a question to remove it.")
                    }

                    Section {
                        ShareLink(item: shareText(for: prep)) {
                            Label("Share your questions", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            viewModel.addToTasks(prep, ownQuestions: ownQuestions)
                            addedToTasks = true
                        } label: {
                            Label(addedToTasks ? "Added to your to do list" : "Add to my to do list",
                                  systemImage: addedToTasks ? "checkmark.circle.fill" : "checklist")
                        }
                        .disabled(addedToTasks)
                    } footer: {
                        Text("Adding them makes a task due on the day, so they turn up on Home and in the Coming up widget.")
                    }
                }
            }
            .navigationTitle("Before your appointment")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(AppColours.sand)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Couldn't write your questions", isPresented: errorAlertBinding) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    /// The marker's readings across every report, oldest first, with the healthy
    /// range, so the question comes with its evidence.
    @ViewBuilder
    private func historyLine(for markerName: String) -> some View {
        let history = viewModel.readingHistory(for: markerName)
        if let latest = history.last {
            let values = history.map { $0.value.formatted() }.joined(separator: " → ")
            let range = latest.referenceRange
            Text(history.count > 1
                 ? "Your readings: \(values) \(latest.unit), healthy range \(range.lowerBound.formatted()) to \(range.upperBound.formatted())"
                 : "Your only reading so far: \(values) \(latest.unit), healthy range \(range.lowerBound.formatted()) to \(range.upperBound.formatted())")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func addOwnQuestion() {
        let question = newQuestion.trimmingCharacters(in: .whitespaces)
        guard !question.isEmpty else { return }
        ownQuestions.append(question)
        newQuestion = ""
        addedToTasks = false  // the list changed, let them add it again
    }

    /// The questions as one note, ready to paste or send.
    private func shareText(for prep: AppointmentPrep) -> String {
        let heading = "Questions for my GP appointment on \(prep.appointmentOn.formatted(date: .long, time: .omitted))"
        let lines = (prep.questions.map(\.question) + ownQuestions).map { "• " + $0 }
        return ([heading, ""] + lines).joined(separator: "\n")
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isShowing in
                guard !isShowing else { return }
                DispatchQueue.main.async { viewModel.errorMessage = nil }
            }
        )
    }
}

#Preview {
    AppointmentQuestionsView(viewModel: FollowUpsViewModel(repository: InMemoryHealthRecordRepository()))
}
