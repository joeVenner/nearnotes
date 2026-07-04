import ActivityKit
import CoreLocation
import Foundation

@MainActor
final class LiveActivityService: ObservableObject {
    static let shared = LiveActivityService()

    @Published private(set) var activeReminderID: UUID?

    private init() {
        activeReminderID = Activity<ReminderActivityAttributes>.activities.first?.attributes.reminderID
    }

    var activitiesAreEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func toggle(reminder: Reminder, distance: Double) async throws {
        if activeReminderID == reminder.id {
            await end(reminderID: reminder.id)
            return
        }

        guard activitiesAreEnabled else { throw LiveActivityError.disabled }
        await endAll()

        let state = ReminderActivityAttributes.ContentState(
            distanceString: Self.distanceText(distance),
            isClose: distance.isFinite && distance <= reminder.radius
        )
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(15 * 60))

        do {
            let activity = try Activity.request(
                attributes: ReminderActivityAttributes(reminder: reminder),
                content: content,
                pushType: nil
            )
            activeReminderID = activity.attributes.reminderID
        } catch {
            throw LiveActivityError.couldNotStart(error.localizedDescription)
        }
    }

    func update(for location: CLLocation) async {
        for activity in Activity<ReminderActivityAttributes>.activities {
            let attributes = activity.attributes
            let destination = CLLocation(latitude: attributes.latitude, longitude: attributes.longitude)
            let distance = location.distance(from: destination)
            let state = ReminderActivityAttributes.ContentState(
                distanceString: Self.distanceText(distance),
                isClose: distance <= attributes.radius
            )
            await activity.update(
                ActivityContent(state: state, staleDate: Date().addingTimeInterval(15 * 60))
            )
        }
        activeReminderID = Activity<ReminderActivityAttributes>.activities.first?.attributes.reminderID
    }

    func end(reminderID: UUID) async {
        for activity in Activity<ReminderActivityAttributes>.activities where activity.attributes.reminderID == reminderID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        activeReminderID = Activity<ReminderActivityAttributes>.activities.first?.attributes.reminderID
    }

    private func endAll() async {
        for activity in Activity<ReminderActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        activeReminderID = nil
    }

    private static func distanceText(_ distance: Double) -> String {
        guard distance.isFinite else { return "Updating…" }
        if distance < 1_000 { return "\(max(0, Int(distance.rounded()))) m" }
        return String(format: "%.1f km", distance / 1_000)
    }
}

enum LiveActivityError: LocalizedError {
    case disabled
    case couldNotStart(String)

    var errorDescription: String? {
        switch self {
        case .disabled:
            "Live Activities are disabled. Enable them in Settings → Apps → NearNote → Live Activities."
        case .couldNotStart(let message):
            "The Lock Screen radar could not start. \(message)"
        }
    }
}

