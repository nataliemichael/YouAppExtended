//
//  ShareViewController.swift
//  YouShare
//

import UIKit
import SwiftUI
import Combine
import UniformTypeIdentifiers

/// The share sheet's entry point. Takes the one photo or PDF the patient shared,
/// drops it in the App Group inbox for the app, shows a short confirmation and
/// closes itself. It never shows a form, the patient fills in nothing here.
///
/// Business rules:
/// - Exactly one report at a time, as a photo or a PDF. Anything else is turned
///   away with a plain message, and the sheet still closes properly.
/// - The extension only saves. Reading the result happens in the app, where the
///   patient picks the marker and confirms the numbers.
final class ShareViewController: UIViewController {
    private let state = ShareState()

    override func viewDidLoad() {
        super.viewDidLoad()

        let screen = UIHostingController(rootView: ShareView(state: state) { [weak self] in
            self?.finish()
        })
        addChild(screen)
        screen.view.frame = view.bounds
        screen.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(screen.view)
        screen.didMove(toParent: self)

        saveSharedReport()
    }

    /// Finds the shared item and hands it to the inbox.
    private func saveSharedReport() {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?
            .flatMap { $0.attachments ?? [] } ?? []

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) }) {
            load(provider, as: .pdf, kind: .pdf)
        } else if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) {
            load(provider, as: .image, kind: .image)
        } else {
            state.outcome = .refused("You can share a photo or a PDF of a report into You. This doesn't look like either.")
        }
    }

    private func load(_ provider: NSItemProvider, as type: UTType, kind: SharedReport.Kind) {
        provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { [weak self] data, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                guard let data, !data.isEmpty else {
                    self.state.outcome = .refused("We couldn't open what was shared. Try sharing the report again from the app it came from.")
                    return
                }
                do {
                    _ = try ReportInbox().receive(data, kind: kind)
                    self.state.outcome = .saved
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.finish() }  // long enough to read, short enough not to nag
                } catch {
                    self.state.outcome = .refused("We couldn't save the report just now. Try again, or add the result in You by hand.")
                }
            }
        }
    }

    /// Hands control back to the app the patient was in. Called on every path.
    private func finish() {
        extensionContext?.completeRequest(returningItems: [])
    }
}

// MARK: - What the sheet shows

/// Where the share has got to, drives the sheet.
final class ShareState: ObservableObject {
    enum Outcome: Equatable {
        case saving
        case saved
        case refused(String)
    }

    @Published var outcome: Outcome = .saving
}

struct ShareView: View {
    @ObservedObject var state: ShareState
    let done: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            icon
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(AppColours.ink)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
            if state.outcome != .saving {
                Button(action: done) {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColours.ink, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColours.sand)
    }

    @ViewBuilder
    private var icon: some View {
        switch state.outcome {
        case .saving:
            ProgressView()
                .controlSize(.large)
        case .saved:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppColours.done)
        case .refused:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppColours.warning)
        }
    }

    private var title: String {
        switch state.outcome {
        case .saving: return "Saving to You…"
        case .saved: return "Saved to You"
        case .refused: return "Couldn't save that"
        }
    }

    private var detail: String {
        switch state.outcome {
        case .saving: return "Just a moment."
        case .saved: return "Open You to record a result from this report. It stays on your phone."
        case .refused(let reason): return reason
        }
    }
}
