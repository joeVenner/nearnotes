import SwiftUI

struct MainView: View {
    @State private var selectedTab = 0
    @State private var showComposer = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var composerPlace: Place?

    var body: some View {
        Group {
            if hasSeenOnboarding {
                TabView(selection: $selectedTab) {
                    HomeView(onAdd: { showComposer = true })
                        .tabItem { Label("Nearby", systemImage: "location.fill") }.tag(0)
                    MapView(onAdd: { place in
                        composerPlace = place
                        showComposer = true
                    })
                        .tabItem { Label("Map", systemImage: "map.fill") }.tag(1)
                    RemindersView(onAdd: { showComposer = true })
                        .tabItem { Label("Reminders", systemImage: "checklist") }.tag(2)
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape.fill") }.tag(3)
                }
                .tint(NearNoteStyle.accent)
            } else {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
            }
        }
        .sheet(isPresented: $showComposer, onDismiss: { composerPlace = nil }) {
            ReminderComposerView(initialPlace: composerPlace)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview { MainView().environmentObject(LocationService.shared).environmentObject(NotificationService.shared) }
