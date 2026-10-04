//
//  ResultsViewModelPhotoTests.swift
//  YouTests
//

import Foundation
import Testing
import UIKit
@testable import You

/// A photo store that only remembers what it was asked to do.
private final class CountingPhotoStore: ReportPhotoStoring {
    var saved: [String] = []
    var removed: [String] = []

    func save(_ photo: Data) throws -> String {
        let fileName = "photo-\(saved.count + 1).jpg"
        saved.append(fileName)
        return fileName
    }

    func load(fileName: String) -> Data? { nil }

    func remove(fileName: String) {
        removed.append(fileName)
    }
}

/// Tests for how `ResultsViewModel.record` looks after the report photo.
@MainActor
struct ResultsViewModelPhotoTests {

    private func makeViewModel() -> (ResultsViewModel, CountingPhotoStore, InMemoryHealthRecordRepository) {
        let repository = InMemoryHealthRecordRepository(results: [], referrals: [], followUpTasks: [])
        let photoStore = CountingPhotoStore()
        let viewModel = ResultsViewModel(repository: repository, photoStore: photoStore)
        return (viewModel, photoStore, repository)
    }

    /// A tiny real image, since an empty `UIImage()` has no JPEG data.
    private var samplePhoto: UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
    }

    @Test func test_record_keepsThePhoto_whenResultWasReadFromOne() {
        let (viewModel, photoStore, repository) = makeViewModel()

        let saved = viewModel.record(
            markerName: "Ferritin", valueText: "9", unit: "µg/L",
            rangeLowText: "30", rangeHighText: "300",
            collectedOn: Date(), orderingClinician: "Dr Michael",
            reportPhoto: samplePhoto
        )

        #expect(saved)
        #expect(photoStore.saved.count == 1)
        #expect(repository.results.first?.reportPhotoFileName == "photo-1.jpg")
    }

    @Test func test_record_removesThePhoto_whenEntryIsRefused() {
        let (viewModel, photoStore, repository) = makeViewModel()

        // 4000 is more than 10× the top of the range, the use case refuses it.
        let saved = viewModel.record(
            markerName: "Ferritin", valueText: "4000", unit: "µg/L",
            rangeLowText: "30", rangeHighText: "300",
            collectedOn: Date(), orderingClinician: "Dr Michael",
            reportPhoto: samplePhoto
        )

        #expect(!saved)
        #expect(photoStore.removed == photoStore.saved)
        #expect(repository.results.isEmpty)
    }

    @Test func test_record_keepsNoPhoto_whenResultWasTypedIn() {
        let (viewModel, photoStore, repository) = makeViewModel()

        let saved = viewModel.record(
            markerName: "Ferritin", valueText: "9", unit: "µg/L",
            rangeLowText: "30", rangeHighText: "300",
            collectedOn: Date(), orderingClinician: "Dr Michael"
        )

        #expect(saved)
        #expect(photoStore.saved.isEmpty)
        #expect(repository.results.first?.reportPhotoFileName == nil)
    }
}
