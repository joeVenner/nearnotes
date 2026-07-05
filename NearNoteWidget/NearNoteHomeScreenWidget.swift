import WidgetKit
import SwiftUI
import SwiftData

struct NearNoteHomeScreenWidget: Widget {
    let kind: String = "NearNoteHomeScreenWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            NearNoteHomeScreenWidgetEntryView(entry: entry)
                .containerBackground(Color("WidgetBackground", bundle: nil).opacity(0.1), for: .widget)
        }
        .configurationDisplayName("Active Reminders")
        .description("Keep track of your active location reminders.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), reminders: [])
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        Task { @MainActor in
            let reminders = fetchReminders()
            completion(SimpleEntry(date: Date(), reminders: reminders))
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task { @MainActor in
            let reminders = fetchReminders()
            let entries = [SimpleEntry(date: Date(), reminders: reminders)]
            let timeline = Timeline(entries: entries, policy: .after(Date().addingTimeInterval(15 * 60)))
            completion(timeline)
        }
    }
    
    @MainActor
    private func fetchReminders() -> [Reminder] {
        let store = ReminderStore.shared
        return store.fetchActive()
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let reminders: [Reminder]
}

struct NearNoteHomeScreenWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "location.north.circle.fill")
                    .foregroundStyle(.green)
                Text("NearNotes")
                    .font(.headline)
                Spacer()
                Text("\(entry.reminders.count)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 4)
            
            if entry.reminders.isEmpty {
                Spacer()
                Text("No active reminders.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                let displayCount = family == .systemSmall ? 2 : (family == .systemMedium ? 2 : 5)
                ForEach(entry.reminders.prefix(displayCount)) { reminder in
                    HStack(alignment: .top) {
                        Button(intent: ToggleReminderIntent(reminderID: reminder.id.uuidString)) {
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reminder.title)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Text(reminder.placeName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 2)
                    
                    if reminder != entry.reminders.prefix(displayCount).last {
                        Divider()
                    }
                }
                Spacer()
            }
        }
        .padding()
    }
}
