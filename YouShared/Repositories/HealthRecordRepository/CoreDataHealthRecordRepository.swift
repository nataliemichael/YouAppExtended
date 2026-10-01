//
//  CoreDataHealthRecordRepository.swift
//  You
//

import CoreData
import WidgetKit

/// The patient's health record store backed by Core Data, saved in the App Group
/// container so records survive relaunch and the widget can read them.
///
/// Business rules:
/// - Records stay on the patient's device. No account, no cloud. This is the
///   app's privacy promise made concrete.
/// - Every change is saved straight away, so nothing is lost if the app is killed.
/// - The domain structs are what the rest of the app sees. Mapping to and from
///   the stored entities happens here and nowhere else.
/// - On first launch the store seeds itself with the sample records, then the
///   database becomes the single source of truth.
final class CoreDataHealthRecordRepository: HealthRecordRepository {
    private let store: HealthRecordStore
    private var context: NSManagedObjectContext { store.context }

    /// The main app seeds sample records on first launch. The widget passes
    /// `seedsSampleRecords: false` because it only ever reads.
    init(store: HealthRecordStore = HealthRecordStore(), seedsSampleRecords: Bool = true) {
        self.store = store
        if seedsSampleRecords { seedIfEmpty() }
    }

    // MARK: - Reading

    var results: [PathologyResult] {
        let request = StoredPathologyResult.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "collectedOn", ascending: false)]
        return fetch(request).compactMap(Self.result(from:))
    }

    var referrals: [Referral] {
        let request = StoredReferral.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "expiresOn", ascending: true)]
        return fetch(request).compactMap(Self.referral(from:))
    }

    var followUpTasks: [FollowUpTask] {
        let request = StoredFollowUpTask.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "dueOn", ascending: true)]
        return fetch(request).compactMap(Self.task(from:))
    }

    // MARK: - Writing

    func add(_ result: PathologyResult) {
        let stored = StoredPathologyResult(context: context)
        stored.id = result.id
        stored.collectedOn = result.collectedOn
        stored.orderingClinician = result.orderingClinician
        for reading in result.markers {
            let storedReading = StoredMarkerReading(context: context)
            storedReading.id = reading.id
            storedReading.markerName = reading.markerName
            storedReading.value = reading.value
            storedReading.unit = reading.unit
            storedReading.rangeLowerBound = reading.referenceRange.lowerBound
            storedReading.rangeUpperBound = reading.referenceRange.upperBound
            storedReading.plainLanguageExplanation = reading.plainLanguageExplanation
            storedReading.result = stored
        }
        save()
    }

    func add(_ referral: Referral) {
        let stored = StoredReferral(context: context)
        stored.id = referral.id
        stored.kind = referral.kind.rawValue
        stored.purpose = referral.purpose
        stored.issuedBy = referral.issuedBy
        stored.issuedOn = referral.issuedOn
        stored.expiresOn = referral.expiresOn
        save()
    }

    func add(_ task: FollowUpTask) {
        let stored = StoredFollowUpTask(context: context)
        stored.id = task.id
        apply(task, to: stored)
        save()
    }

    func update(_ task: FollowUpTask) {
        guard let stored = storedTask(id: task.id) else { return }
        apply(task, to: stored)
        save()
    }

    func delete(_ result: PathologyResult) {
        let request = StoredPathologyResult.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", result.id as CVarArg)
        fetch(request).forEach(context.delete)  // cascade removes its readings
        save()
    }

    // MARK: - Domain queries

    func followUpTasksDue(withinDays days: Int, on date: Date) -> [FollowUpTask] {
        let cutoff = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
        let request = StoredFollowUpTask.fetchRequest()
        request.predicate = NSPredicate(
            format: "completedOn == nil AND dueOn <= %@",
            cutoff as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(key: "dueOn", ascending: true)]
        return fetch(request).compactMap(Self.task(from:))
    }

    func referralsExpiring(withinDays days: Int, on date: Date) -> [Referral] {
        let today = Calendar.current.startOfDay(for: date)
        let cutoff = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
        let request = StoredReferral.fetchRequest()
        request.predicate = NSPredicate(
            format: "expiresOn >= %@ AND expiresOn <= %@",
            today as NSDate, cutoff as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(key: "expiresOn", ascending: true)]
        return fetch(request).compactMap(Self.referral(from:))
    }

    func flaggedReadings(since: Date) -> [MarkerReading] {
        let request = StoredMarkerReading.fetchRequest()
        // "Flagged" in the database's own words: outside the lab's healthy range.
        request.predicate = NSPredicate(
            format: "result.collectedOn >= %@ AND (value < rangeLowerBound OR value > rangeUpperBound)",
            since as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(key: "result.collectedOn", ascending: false)]
        return fetch(request).compactMap(Self.reading(from:))
    }

    func readingHistory(forMarker markerName: String) -> [MarkerReading] {
        let request = StoredMarkerReading.fetchRequest()
        request.predicate = NSPredicate(format: "markerName ==[c] %@", markerName)  // [c] ignores case
        request.sortDescriptors = [NSSortDescriptor(key: "result.collectedOn", ascending: true)]
        return fetch(request).compactMap(Self.reading(from:))
    }

    // MARK: - Helpers

    private func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) -> [T] {
        (try? context.fetch(request)) ?? []
    }

    private func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
            // Every relevant data change ends here, so this is where the main app
            // tells the Coming up widget to redraw from the shared store.
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            context.rollback()
            print("Failed to save health record: \(error)")
        }
    }

    private func storedTask(id: UUID) -> StoredFollowUpTask? {
        let request = StoredFollowUpTask.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return fetch(request).first
    }

    private func storedReferral(id: UUID) -> StoredReferral? {
        let request = StoredReferral.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return fetch(request).first
    }

    private func apply(_ task: FollowUpTask, to stored: StoredFollowUpTask) {
        stored.title = task.title
        stored.detail = task.detail
        stored.dueOn = task.dueOn
        stored.completedOn = task.completedOn
        stored.referral = task.referralID.flatMap(storedReferral(id:))
    }

    /// First launch only: fill the empty store with the sample records so the
    /// screens have something to show.
    private func seedIfEmpty() {
        let count = (try? context.count(for: StoredPathologyResult.fetchRequest())) ?? 0
        let referralCount = (try? context.count(for: StoredReferral.fetchRequest())) ?? 0
        guard count == 0, referralCount == 0 else { return }
        SampleData.results.forEach(add)
        SampleData.referrals.forEach(add)
        SampleData.followUpTasks.forEach(add)
    }

    // MARK: - Mapping stored entities to domain structs

    nonisolated private static func result(from stored: StoredPathologyResult) -> PathologyResult? {
        guard let id = stored.id, let collectedOn = stored.collectedOn else { return nil }
        let readings = (stored.markers as? Set<StoredMarkerReading> ?? [])
            .compactMap(reading(from:))
            .sorted { $0.markerName < $1.markerName }
        return PathologyResult(
            id: id,
            collectedOn: collectedOn,
            orderingClinician: stored.orderingClinician ?? "",
            markers: readings
        )
    }

    nonisolated private static func reading(from stored: StoredMarkerReading) -> MarkerReading? {
        guard let id = stored.id, let markerName = stored.markerName else { return nil }
        return MarkerReading(
            id: id,
            markerName: markerName,
            value: stored.value,
            unit: stored.unit ?? "",
            referenceRange: ReferenceRange(
                lowerBound: stored.rangeLowerBound,
                upperBound: stored.rangeUpperBound
            ),
            plainLanguageExplanation: stored.plainLanguageExplanation ?? ""
        )
    }

    nonisolated private static func referral(from stored: StoredReferral) -> Referral? {
        guard let id = stored.id,
              let kind = Referral.Kind(rawValue: stored.kind ?? ""),
              let issuedOn = stored.issuedOn,
              let expiresOn = stored.expiresOn else { return nil }
        return Referral(
            id: id,
            kind: kind,
            purpose: stored.purpose ?? "",
            issuedBy: stored.issuedBy ?? "",
            issuedOn: issuedOn,
            expiresOn: expiresOn
        )
    }

    nonisolated private static func task(from stored: StoredFollowUpTask) -> FollowUpTask? {
        guard let id = stored.id, let dueOn = stored.dueOn else { return nil }
        return FollowUpTask(
            id: id,
            title: stored.title ?? "",
            detail: stored.detail,
            dueOn: dueOn,
            completedOn: stored.completedOn,
            referralID: stored.referral?.id
        )
    }
}
