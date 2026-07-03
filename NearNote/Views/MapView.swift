import SwiftUI
import SwiftData
import MapKit

struct MapView: View {
    var onAdd: (Place?) -> Void = { _ in }
    @Query private var reminders: [Reminder]
    @EnvironmentObject private var locationService: LocationService
    @State private var position: MapCameraPosition = .automatic
    @State private var selected: Reminder?
    @State private var showLocationPicker = false

    private var activeReminders: [Reminder] {
        reminders
            .filter { !$0.isCompleted && !$0.isArchived && $0.isEnabled }
            .sorted { $0.placeName.localizedCaseInsensitiveCompare($1.placeName) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NearNoteBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        mapHero
                        placesList
                    }
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selected) { ReminderComposerView(reminder: $0) }
            .fullScreenCover(isPresented: $showLocationPicker) {
                LocationPickerView(onPlaceSelected: { place in onAdd(place) })
            }
            .onAppear { locationService.startInUseTracking() }
            .onDisappear { locationService.stopInUseTracking() }
        }
    }

    private var mapHero: some View {
        ZStack(alignment: .top) {
            Map(position: $position) {
                UserAnnotation()
                ForEach(activeReminders) { reminder in
                    Annotation(reminder.placeName, coordinate: reminder.coordinate) {
                        Button { selected = reminder } label: {
                            PlaceIcon(category: reminder.category, size: 36)
                                .overlay {
                                    Circle().stroke(.white.opacity(0.7), lineWidth: 1)
                                }
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .mapControls { MapCompass() }
            .frame(height: 440)

            LinearGradient(
                colors: [NearNoteStyle.canvas.opacity(0.92), .clear, NearNoteStyle.canvas],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            HStack(spacing: 10) {
                Button { showLocationPicker = true } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "magnifyingglass")
                        Text("Search for a place")
                            .font(.subheadline)
                            .foregroundStyle(NearNoteStyle.secondaryText)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)

                Button { centerOnUser() } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 46, height: 46)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Center on my location")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
        }
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your places")
                    .font(.largeTitle.bold())
                Text("\(activeReminders.count) active reminder\(activeReminders.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(NearNoteStyle.secondaryText)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }

    private var placesList: some View {
        LazyVStack(spacing: 12) {
            if activeReminders.isEmpty {
                VStack(spacing: 10) {
                    Image("pebble_idle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 132, height: 112)
                    Text("No places yet").font(.title3.bold())
                    Text("Add a reminder to place it on your map.")
                        .font(.subheadline)
                        .foregroundStyle(NearNoteStyle.secondaryText)
                    Button("Add Reminder", systemImage: "plus") { onAdd(nil) }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ForEach(activeReminders) { reminder in
                    HStack(spacing: 12) {
                        Button { show(reminder) } label: {
                            HStack(spacing: 12) {
                            PlaceIcon(category: reminder.category, size: 42)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(reminder.placeName)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(reminder.title)
                                    .font(.caption)
                                    .foregroundStyle(NearNoteStyle.secondaryText)
                                    .lineLimit(1)
                            }
                            Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        Button { selected = reminder } label: {
                            Image(systemName: "ellipsis")
                                .frame(width: 36, height: 36)
                                .background(NearNoteStyle.raisedSurface, in: Circle())
                        }
                        .accessibilityLabel("Edit \(reminder.title)")
                    }
                    .padding(14)
                    .background(NearNoteStyle.surface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func centerOnUser() {
        guard let coordinate = locationService.currentLocation?.coordinate else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            position = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 1_200, longitudinalMeters: 1_200))
        }
    }

    private func show(_ reminder: Reminder) {
        withAnimation(.easeInOut(duration: 0.35)) {
            position = .region(MKCoordinateRegion(center: reminder.coordinate, latitudinalMeters: 900, longitudinalMeters: 900))
        }
    }
}

#Preview { MapView().environmentObject(LocationService.shared) }
