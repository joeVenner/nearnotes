import ActivityKit
import Foundation

public struct ReminderActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var distanceString: String
        public var isClose: Bool

        public init(distanceString: String, isClose: Bool) {
            self.distanceString = distanceString
            self.isClose = isClose
        }
    }

    public var reminderID: UUID
    public var reminderTitle: String
    public var placeName: String
    public var latitude: Double
    public var longitude: Double
    public var radius: Double

    public init(reminder: Reminder) {
        reminderID = reminder.id
        reminderTitle = reminder.title
        placeName = reminder.placeName
        latitude = reminder.latitude
        longitude = reminder.longitude
        radius = reminder.radius
    }
}

