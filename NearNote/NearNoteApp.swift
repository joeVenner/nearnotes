import SwiftUI
import SwiftData

@main
struct NearNoteApp: App {
    
    @StateObject private var locationService = LocationService.shared
    @StateObject private var notificationService = NotificationService.shared
    
    init() {
        // Instantiate singletons early to ensure delegates
        _ = LocationService.shared
        _ = NotificationService.shared
        _ = GeofenceManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(locationService)
                .environmentObject(notificationService)
                .task {
                    // Refresh geofences when app is launched
                    await locationService.updateMonitoredRegions()
                    TelemetryService.shared.track(.appOpened)
                }
        }
        .modelContainer(ReminderStore.shared.container)
    }
}
