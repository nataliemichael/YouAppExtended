//
//  ReportPhotoStore.swift
//  You
//

import Foundation

/// Anything that can keep photos of paper reports by file name. The app uses the
/// App Group folder; tests use a fake that only counts.
protocol ReportPhotoStoring {
    /// Saves the photo and returns the file name to keep with the result.
    func save(_ photo: Data) throws -> String
    func load(fileName: String) -> Data?
    func remove(fileName: String)
}

/// Keeps report photos as JPEG files in a folder inside the App Group container,
/// next to the database.
///
/// Business rules:
/// - Only the file name is stored in Core Data. Images stay out of the database so
///   every fetch of results stays fast, and the Share Extension can later drop
///   photos into this same folder for the app to pick up.
/// - Photos never leave the device, like every other record.
/// - A photo belongs to one result. When the result is deleted, so is the photo.
nonisolated final class ReportPhotoStore: ReportPhotoStoring {
    private let folder: URL

    init() {
        let base = AppGroup.containerURL
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        folder = base.appendingPathComponent("ReportPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func save(_ photo: Data) throws -> String {
        let fileName = UUID().uuidString + ".jpg"
        try photo.write(to: url(for: fileName), options: .atomic)
        return fileName
    }

    func load(fileName: String) -> Data? {
        try? Data(contentsOf: url(for: fileName))
    }

    func remove(fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    private func url(for fileName: String) -> URL {
        folder.appendingPathComponent(fileName)
    }
}
