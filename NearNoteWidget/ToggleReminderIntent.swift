import AppIntents
import SwiftData
import Foundation

struct ToggleReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Reminder"
    static var description = IntentDescription("Marks a reminder as completed.")

    @Parameter(title: "Reminder ID")
    var reminderID: String

    init() {}

    init(reminderID: String) {
        self.reminderID = reminderID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let store = ReminderStore.shared
        if let id = UUID(uuidString: reminderID),
           let reminder = store.fetchReminder(withId: id) {
            reminder.markDone()
            store.save()
        }
        return .result()
    }
}
