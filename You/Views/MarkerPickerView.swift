//
//  MarkerPickerView.swift
//  You
//

import SwiftUI

/// Which marker the patient is recording: one the app knows, or one typed in.
enum MarkerChoice: Hashable {
    case known(KnownMarker)
    case other
}

/// The list of markers the app knows, grouped the way reports print them, with
/// "Other" at the end for anything not listed. Tapping one chooses it and goes back.
struct MarkerPickerView: View {
    @Binding var choice: MarkerChoice?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(KnownMarker.Group.allCases, id: \.self) { group in
                Section(group.rawValue) {
                    ForEach(KnownMarker.all.filter { $0.group == group }) { marker in
                        row(title: marker.name, unit: marker.unit, value: .known(marker))
                    }
                }
            }
            Section("Not listed") {
                row(title: "Other, I'll type it in", unit: nil, value: .other)
            }
        }
        .navigationTitle("Marker")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppColours.sand)
    }

    private func row(title: String, unit: String?, value: MarkerChoice) -> some View {
        Button {
            choice = value
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(Color.primary)
                    if let unit {
                        Text(unit)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if choice == value {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColours.ink)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        MarkerPickerView(choice: .constant(.known(KnownMarker.all[3])))
    }
}
