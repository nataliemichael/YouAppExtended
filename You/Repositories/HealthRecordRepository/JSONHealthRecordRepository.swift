//
//  JSONHealthRecordRepository.swift
//  You
//

import Foundation

/// A health record store saved as a JSON file in the app's private Documents folder,
/// so the patient's records survive closing the app but never leave the device.
///
/// Business rules:
/// - Records live on the patient's device only, no account, no cloud. This is the
///   app's privacy promise made concrete.
/// - Every change writes the whole file atomically, so a crash mid-save can never
///   leave the record half-written.
/// - On first launch the store seeds itself with the sample records, then the file
///   becomes the single source of truth.
final class JSONHealthRecordRepository: HealthRecordRepository {
    private(set) var results: [PathologyResult] = []
    private(set) var referrals: [Referral] = []
    private(set) var followUpTasks: [FollowUpTask] = []

    /// Everything the store holds, as it is laid out in the file.
    private struct HealthRecordFile: Codable {
        var results: [PathologyResult]
        var referrals: [Referral]
        var followUpTasks: [FollowUpTask]
    }

    private let fileURL: URL

    init() {
        let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        fileURL = documentsURL.appendingPathComponent("HealthRecord.json")

        if let data = try? Data(contentsOf: fileURL),
           let file = try? JSONDecoder().decode(HealthRecordFile.self, from: data) {
            results = file.results
            referrals = file.referrals
            followUpTasks = file.followUpTasks
        } else {
            // First launch (or an unreadable file): start from the sample records.
            results = SampleData.results
            referrals = SampleData.referrals
            followUpTasks = SampleData.followUpTasks
            save()
        }
    }

    func add(_ result: PathologyResult) {
        results.append(result)
        save()
    }

    func add(_ referral: Referral) {
        referrals.append(referral)
        save()
    }

    func add(_ task: FollowUpTask) {
        followUpTasks.append(task)
        save()
    }

    func update(_ task: FollowUpTask) {
        guard let index = followUpTasks.firstIndex(where: { $0.id == task.id }) else { return }
        followUpTasks[index] = task
        save()
    }

    private func save() {
        let file = HealthRecordFile(
            results: results,
            referrals: referrals,
            followUpTasks: followUpTasks
        )
        do {
            let data = try JSONEncoder().encode(file)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save health record: \(error)")
        }
    }
}
