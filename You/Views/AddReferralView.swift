//
//  AddReferralView.swift
//  You
//

import SwiftUI

/// The form for tracking a referral the patient was handed, so it can't quietly
/// expire in a drawer. Saving books the reminder task automatically.
struct AddReferralView: View {
    @ObservedObject var viewModel: FollowUpsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var kind: Referral.Kind = .pathology
    @State private var purpose: String = ""
    @State private var issuedBy: String = ""
    @State private var issuedOn: Date = Date()
    @State private var expiresOn: Date = Date()

    private var isMissingRequiredFields: Bool {
        purpose.trimmingCharacters(in: .whitespaces).isEmpty
            || issuedBy.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("From the paper referral") {
                    Picker("Referral type", selection: $kind) {
                        Text("Pathology (blood test)").tag(Referral.Kind.pathology)
                        Text("Specialist").tag(Referral.Kind.specialist)
                        Text("Imaging (scan or X-ray)").tag(Referral.Kind.imaging)
                    }
                    TextField("What it's for, e.g. Iron studies re-check", text: $purpose)
                    TextField("Written by, e.g. Dr Michael", text: $issuedBy)
                }

                Section("Dates on the referral") {
                    DatePicker("Written on", selection: $issuedOn, displayedComponents: .date)
                    DatePicker("Use by", selection: $expiresOn, displayedComponents: .date)
                }

                Section {
                    Text("You'll get a follow-up reminder three days before it expires.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Track a referral")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(AppColours.paleTeal)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start tracking", systemImage: "checkmark") { save() }
                        .disabled(isMissingRequiredFields)
                }
            }
            .alert("Couldn't track this referral", isPresented: errorAlertBinding) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private func save() {
        let saved = viewModel.track(
            kind: kind,
            purpose: purpose,
            issuedBy: issuedBy,
            issuedOn: issuedOn,
            expiresOn: expiresOn
        )
        if saved { dismiss() }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

#Preview {
    AddReferralView(viewModel: FollowUpsViewModel(repository: InMemoryHealthRecordRepository()))
}
