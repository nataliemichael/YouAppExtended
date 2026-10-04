//
//  HealthRecordStore.swift
//  You
//

import CoreData

/// The App Group every part of You shares. The main app, the widget and the
/// share extension all read the same identifier, so it lives in one place.
nonisolated enum AppGroup {
    static let identifier = "group.com.nootnoot.You"

    /// The shared folder the App Group gives us, or nil outside the group
    /// (for example in SwiftUI previews).
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}

/// Opens the patient's Core Data record store and hands out its context.
///
/// Business rules:
/// - The store file lives in the App Group container, not the app's private
///   Documents folder, so the widget can read the same records the app writes.
/// - The schema is kept CloudKit-ready (optional attributes, inverse
///   relationships) so sync could be switched on later without a rewrite.
/// - Only the repository talks to this store. Views and ViewModels never see it.
final class HealthRecordStore {
    let container: NSPersistentContainer

    var context: NSManagedObjectContext {
        container.viewContext
    }

    /// Opens the store on disk. Pass `inMemory: true` for previews and tests
    /// that want a throwaway store.
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "HealthRecord")

        let description = container.persistentStoreDescriptions.first ?? NSPersistentStoreDescription()
        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        } else {
            description.url = Self.storeURL
        }
        description.shouldMigrateStoreAutomatically = true  // adding an entity later just works
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error {
                // A store that can't open means no records at all, which the app can't
                // recover from on its own, so fail loudly during development.
                fatalError("Couldn't open the health record store: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Where the store file sits: inside the App Group when available, otherwise
    /// the app's own Documents folder so the app still runs outside the group.
    private static var storeURL: URL {
        let folder = AppGroup.containerURL
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return folder.appendingPathComponent("HealthRecord.sqlite")
    }
}
