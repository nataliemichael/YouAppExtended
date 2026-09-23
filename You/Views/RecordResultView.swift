//
//  RecordResultView.swift
//  You
//

import SwiftUI

/// The form for typing in one marker from a paper pathology report.
///
/// Two layers guard against typing mistakes: the app refuses entries that could not
/// come from a lab report (the use case's business rules), and everything else gets a
/// "does this match your report?" confirmation, only the patient, holding the paper,
/// can catch a believable-but-wrong value like 140 typed instead of 14.
struct RecordResultView: View {
    @ObservedObject var viewModel: ResultsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var markerName: String = ""
    @State private var valueText: String = ""
    @State private var unit: String = ""
    @State private var rangeLowText: String = ""
    @State private var rangeHighText: String = ""
    @State private var collectedOn: Date = Date()
    @State private var orderingClinician: String = ""

    @State private var isConfirming = false

    private var isMissingRequiredFields: Bool {
        markerName.trimmingCharacters(in: .whitespaces).isEmpty
            || valueText.trimmingCharacters(in: .whitespaces).isEmpty
            || rangeLowText.trimmingCharacters(in: .whitespaces).isEmpty
            || rangeHighText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("From your report") {
                    TextField("Marker, e.g. Ferritin", text: $markerName)
                    TextField("Value, e.g. 9", text: $valueText)
                        .keyboardType(.decimalPad)
                    TextField("Unit, e.g. µg/L", text: $unit)
                }

                Section("Healthy range on your report") {
                    TextField("Low end, e.g. 30", text: $rangeLowText)
                        .keyboardType(.decimalPad)
                    TextField("High end, e.g. 300", text: $rangeHighText)
                        .keyboardType(.decimalPad)
                }

                Section("About the test") {
                    DatePicker("Collected on", selection: $collectedOn, displayedComponents: .date)
                    TextField("Ordered by, e.g. Dr Michael", text: $orderingClinician)
                }

                Section {
                    Text("Copy the numbers exactly as they appear on your report. You'll be asked to confirm before anything is saved.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add a result")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(AppColours.paleTeal)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save result", systemImage: "checkmark") { isConfirming = true }
                        .disabled(isMissingRequiredFields)
                }
            }
            .alert("Does this match your report?", isPresented: $isConfirming) {
                Button("Yes, save it") { save() }
                Button("Go back", role: .cancel) {}
            } message: {
                Text("\(markerName), \(valueText) \(unit), collected \(collectedOn.formatted(date: .abbreviated, time: .omitted)). Only you can check this against the paper.")
            }
            .alert("Couldn't save this result", isPresented: errorAlertBinding) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private func save() {
        let saved = viewModel.record(
            markerName: markerName,
            valueText: valueText,
            unit: unit,
            rangeLowText: rangeLowText,
            rangeHighText: rangeHighText,
            collectedOn: collectedOn,
            orderingClinician: orderingClinician
        )
        if saved { dismiss() }
    }

    /// Shows the error alert whenever the ViewModel has a message, and clears the
    /// message when the alert is dismissed.
    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

#Preview {
    RecordResultView(viewModel: ResultsViewModel(repository: InMemoryHealthRecordRepository()))
}
