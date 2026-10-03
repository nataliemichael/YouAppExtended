//
//  RecordResultView.swift
//  You
//

import SwiftUI
import PhotosUI
import UIKit

/// The form for recording one marker from a paper pathology report.
///
/// The patient picks the marker from the list, which fills the unit, then either
/// types the numbers or photographs the report and lets the app read them. Two
/// layers guard against mistakes either way: the app refuses entries that could
/// not come from a lab report (the use case's business rules), and everything
/// else gets a "does this match your report?" confirmation, because only the
/// patient, holding the paper, can catch a believable-but-wrong value.
struct RecordResultView: View {
    @ObservedObject var viewModel: ResultsViewModel
    @Environment(\.dismiss) private var dismiss

    /// Which marker is being recorded: one the app knows, or one typed in.
    private enum MarkerChoice: Hashable {
        case known(KnownMarker)
        case other
    }

    @State private var markerChoice: MarkerChoice?
    @State private var markerName: String = ""
    @State private var valueText: String = ""
    @State private var unit: String = ""
    @State private var rangeLowText: String = ""
    @State private var rangeHighText: String = ""
    @State private var collectedOn: Date = Date()
    @State private var orderingClinician: String = ""

    @State private var isTakingPhoto = false
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var isReadingPhoto = false
    @State private var readLine: ReportLine?

    @State private var isConfirming = false
    @State private var errorTitle = "Couldn't save this result"

    private var chosenMarker: KnownMarker? {
        if case .known(let marker) = markerChoice { return marker }
        return nil
    }

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
                    markerPicker
                    if markerChoice == .other {
                        TextField("Marker, e.g. Zinc", text: $markerName)
                    }
                    TextField("Value, e.g. 9", text: $valueText)
                        .keyboardType(.decimalPad)
                    TextField("Unit, e.g. µg/L", text: $unit)
                }

                if let marker = chosenMarker {
                    photoSection(for: marker)
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
            .background(AppColours.sand)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save result", systemImage: "checkmark") { isConfirming = true }
                        .disabled(isMissingRequiredFields)
                }
            }
            .onChange(of: markerChoice) { _, choice in
                markerChosen(choice)
            }
            .onChange(of: pickedPhoto) { _, item in
                guard let item else { return }
                Task { await read(from: item) }
            }
            .fullScreenCover(isPresented: $isTakingPhoto) {
                CameraPicker { photo in
                    Task { await read(photo) }
                }
                .ignoresSafeArea()
            }
            .alert("Does this match your report?", isPresented: $isConfirming) {
                Button("Yes, save it") { save() }
                Button("Go back", role: .cancel) {}
            } message: {
                Text("\(markerName), \(valueText) \(unit), collected \(collectedOn.formatted(date: .abbreviated, time: .omitted)). Only you can check this against the paper.")
            }
            .alert(errorTitle, isPresented: errorAlertBinding) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Pieces

    /// The markers the app knows, grouped the way reports print them, plus "Other".
    private var markerPicker: some View {
        Picker("Marker", selection: $markerChoice) {
            ForEach(KnownMarker.Group.allCases, id: \.self) { group in
                Section(group.rawValue) {
                    ForEach(KnownMarker.all.filter { $0.group == group }) { marker in
                        Text(marker.name).tag(MarkerChoice.known(marker) as MarkerChoice?)
                    }
                }
            }
            Section("Not listed") {
                Text("Other, I'll type it in").tag(MarkerChoice.other as MarkerChoice?)
            }
        }
        .pickerStyle(.navigationLink)
    }

    /// Photograph the report, or pick a photo, and let the app read the numbers.
    private func photoSection(for marker: KnownMarker) -> some View {
        Section {
            if CameraPicker.isAvailable {
                Button("Take a photo of the report", systemImage: "camera") {
                    isTakingPhoto = true
                }
            }
            PhotosPicker(selection: $pickedPhoto, matching: .images) {
                Label("Choose a photo of the report", systemImage: "photo.on.rectangle")
            }
            if isReadingPhoto {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Reading your report…")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Or read it from a photo")
        } footer: {
            Text(photoFooter(for: marker))
        }
    }

    private func photoFooter(for marker: KnownMarker) -> String {
        guard let readLine else {
            return "Point the camera at the \(marker.name) line. You'll still check the numbers before saving."
        }
        var text = "We read: \(readLine.sourceText)"
        if !readLine.hasRange {
            text += " The report didn't print a low and high, so add those from the paper."
        }
        return text
    }

    // MARK: - Actions

    /// Picking a marker fills the unit for them. Picking Other clears it to be typed.
    private func markerChosen(_ choice: MarkerChoice?) {
        readLine = nil
        switch choice {
        case .known(let marker):
            markerName = marker.name
            unit = marker.unit
        case .other:
            markerName = ""
            unit = ""
        case nil:
            break
        }
    }

    private func read(from item: PhotosPickerItem) async {
        defer { pickedPhoto = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let photo = UIImage(data: data) else {
            errorTitle = "Couldn't read the photo"
            viewModel.errorMessage = "We couldn't open that photo. Try choosing it again, or type the result in from the paper."
            return
        }
        await read(photo)
    }

    /// Reads the chosen marker off the photo and fills in what it found.
    private func read(_ photo: UIImage) async {
        guard let marker = chosenMarker else { return }
        errorTitle = "Couldn't read the photo"
        isReadingPhoto = true
        defer { isReadingPhoto = false }

        guard let line = await viewModel.readReport(for: marker, from: photo) else { return }
        readLine = line
        valueText = line.valueText
        if let low = line.rangeLowText, let high = line.rangeHighText {
            rangeLowText = low
            rangeHighText = high
        }
    }

    private func save() {
        errorTitle = "Couldn't save this result"
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
