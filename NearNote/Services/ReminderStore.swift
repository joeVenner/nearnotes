import Foundation
import SwiftData
import CoreLocation
import OSLog

@MainActor
public final class ReminderStore: ObservableObject {
    public static let shared = ReminderStore()
    private static let logger = Logger(subsystem: "com.mosaab.NearNote", category: "Persistence")
    
    public let container: ModelContainer
    public let context: ModelContext
    
    private init() {
        do {
            let schema = Schema([Reminder.self, SavedPlace.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, groupContainer: .identifier("group.com.mosaab.NearNote"), cloudKitDatabase: .automatic)
            let container = try ModelContainer(for: schema, configurations: [config])
            self.container = container
            self.context = container.mainContext
        } catch {
            // Never delete the user's on-device reminders as an automatic recovery action.
            // Added V1 fields all have defaults so SwiftData can perform a lightweight migration.
            fatalError("Unable to open the NearNote store without risking user data: \(error)")
        }
    }
    
    /// Initializer for testing/preview purposes (inMemory: true)
    public init(inMemory: Bool) {
        do {
            let schema = Schema([Reminder.self, SavedPlace.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, groupContainer: .identifier("group.com.mosaab.NearNote"), cloudKitDatabase: .automatic)
            let container = try ModelContainer(for: schema, configurations: [config])
            self.container = container
            self.context = container.mainContext
        } catch {
            fatalError("Failed to initialize in-memory SwiftData ModelContainer: \(error)")
        }
    }
    
    public func fetchAll() -> [Reminder] {
        let descriptor = FetchDescriptor<Reminder>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        do {
            return try context.fetch(descriptor)
        } catch {
            Self.logger.error("Failed to fetch reminders: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
    
    public func fetchActive() -> [Reminder] {
        fetchAll().filter { !$0.isCompleted && !$0.isArchived && $0.isEnabled }
    }
    
    public func fetchReminder(withId id: UUID) -> Reminder? {
        fetchAll().first { $0.id == id }
    }
    
    public func add(_ reminder: Reminder) {
        context.insert(reminder)
        save()
    }
    
    public func delete(_ reminder: Reminder) {
        context.delete(reminder)
        save()
    }
    
    public func save() {
        do {
            try context.save()
        } catch {
            Self.logger.error("Failed to save reminders: \(error.localizedDescription, privacy: .public)")
        }
    }
}
