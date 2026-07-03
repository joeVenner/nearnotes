import SwiftUI
import SwiftData
import CoreLocation
import MapKit

struct HomeView: View {
    let onAdd: () -> Void
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var locationService: LocationService
    @Query private var reminders: [Reminder]
    @State private var editingReminder: Reminder?
    @State private var showPermissions = false
    @State private var showCompletion = false

    private struct NearbyItem: Identifiable {
        let reminder: Reminder
        let distance: Double
        var id: UUID { reminder.id }
    }

    private var active: [NearbyItem] {
        reminders
            .filter { !$0.isCompleted && !$0.isArchived && $0.isEnabled }
            .map { reminder in
                let destination = CLLocation(latitude: reminder.latitude, longitude: reminder.longitude)
                return NearbyItem(
                    reminder: reminder,
                    distance: locationService.currentLocation?.distance(from: destination) ?? .infinity
                )
            }
            .sorted { $0.distance < $1.distance }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NearNoteBackground()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        locationStatus

                        if active.isEmpty {
                            emptyState
                        } else {
                            ForEach(active.prefix(5)) { item in
                                NearbyReminderCard(
                                    reminder: item.reminder,
                                    distance: item.distance,
                                    onComplete: { complete(item.reminder) },
                                    onArchive: { archive(item.reminder) },
                                    onNavigate: { navigate(to: item.reminder) },
                                    onEdit: { editingReminder = item.reminder }
                                )
                            }

                            if active.count > 5 || reminders.contains(where: \.isCompleted) {
                                NavigationLink {
                                    RemindersView(onAdd: onAdd)
                                } label: {
                                    HStack {
                                        Text("See all reminders")
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Text("\(reminders.count)")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white.opacity(0.8))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(.white.opacity(0.12), in: Capsule())
                                    }
                                    .foregroundStyle(.white)
                                    .padding(15)
                                    .background(NearNoteStyle.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Nearby")
            .toolbarBackground(NearNoteStyle.canvas.opacity(0.92), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 38, height: 38)
                            .background(NearNoteStyle.surface, in: Circle())
                    }
                    .accessibilityLabel("New reminder")
                }
            }
            .sheet(item: $editingReminder) { ReminderComposerView(reminder: $0) }
            .sheet(isPresented: $showPermissions) { PermissionEducationView() }
            .overlay { completionOverlay }
            .task {
                locationService.requestCurrentLocation()
                await locationService.updateMonitoredRegions()
            }
        }
    }

    private var locationStatus: some View {
        Button { if locationService.currentLocation == nil { showPermissions = true } } label: {
            HStack(spacing: 12) {
                Image(systemName: locationService.currentLocation == nil ? "location.slash.fill" : "location.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(locationService.currentLocation == nil ? .orange : NearNoteStyle.accent)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(locationService.currentLocation == nil ? "Location is off" : "Near you now")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(locationService.currentLocation == nil ? "Tap to review access" : "Updated just now")
                        .font(.caption)
                        .foregroundStyle(NearNoteStyle.secondaryText)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 42)
            Image("pebble_empty")
                .resizable()
                .scaledToFit()
                .frame(width: 190, height: 150)
                .accessibilityHidden(true)
            Text("Nothing nearby")
                .font(.title2.bold())
            Text("Pebble is watching your places.\nNearby reminders will appear here.")
                .font(.subheadline)
                .foregroundStyle(NearNoteStyle.secondaryText)
                .lineSpacing(3)
            Button("Add Reminder", systemImage: "plus", action: onAdd)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
            Spacer(minLength: 50)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    @ViewBuilder private var completionOverlay: some View {
        if showCompletion {
            Image("pebble_completed")
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 190)
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .transition(.scale(scale: 0.82).combined(with: .opacity))
                .allowsHitTesting(false)
        }
    }

    private func complete(_ reminder: Reminder) {
        withAnimation(.snappy) {
            reminder.markDone()
            GeofenceManager.shared.stop(reminder: reminder)
            try? modelContext.save()
        }
        TelemetryService.shared.track(.reminderCompleted)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) { showCompletion = true }
        Task {
            try? await Task.sleep(for: .seconds(1.1))
            withAnimation { showCompletion = false }
        }
    }

    private func archive(_ reminder: Reminder) {
        withAnimation(.snappy) {
            reminder.archive()
            GeofenceManager.shared.stop(reminder: reminder)
            try? modelContext.save()
        }
        TelemetryService.shared.track(.reminderArchived)
        Task { await locationService.updateMonitoredRegions() }
    }

    private func navigate(to reminder: Reminder) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: reminder.coordinate))
        item.name = reminder.placeName
        item.openInMaps()
    }
}

struct NearbyReminderCard: View {
    let reminder: Reminder
    let distance: Double
    let onComplete: () -> Void
    let onArchive: () -> Void
    let onNavigate: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 13) {
                PlaceIcon(category: reminder.category, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(reminder.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(reminder.placeName)
                        .font(.caption)
                        .foregroundStyle(NearNoteStyle.secondaryText)
                        .lineLimit(1)
                    Text(distance.isFinite ? "\(distance.distanceText) away" : triggerLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(NearNoteStyle.accent)
                }
                Spacer(minLength: 8)
                Menu {
                    Button("Complete", systemImage: "checkmark.circle", action: onComplete)
                    Button("Navigate", systemImage: "location.fill", action: onNavigate)
                    Button("Edit", systemImage: "pencil", action: onEdit)
                    Button("Archive", systemImage: "archivebox", action: onArchive)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.78))
                        .frame(width: 32, height: 40)
                        .contentShape(Rectangle())
                }
            }
            .padding(14)
            .background(NearNoteStyle.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(NearNoteStyle.hairline, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens reminder details. More actions are available at the end of the row.")
    }

    private var triggerLabel: String {
        reminder.triggerMode == .similarCategory ? "Any nearby \(reminder.category?.title.lowercased() ?? "similar place")" : "On arrival"
    }
}

struct RemindersView: View {
    let onAdd: () -> Void
    @Query(sort: \Reminder.createdAt, order: .reverse) private var reminders: [Reminder]
    @State private var selected: Reminder?

    @Environment(\.modelContext) private var modelContext
    private var active: [Reminder] { reminders.filter { !$0.isCompleted && !$0.isArchived } }
    private var completed: [Reminder] { reminders.filter { $0.isCompleted && !$0.isArchived } }
    private var archived: [Reminder] { reminders.filter(\.isArchived) }

    var body: some View {
        NavigationStack {
            ZStack {
                NearNoteBackground()
                if reminders.isEmpty {
                    ContentUnavailableView {
                        Label("No reminders yet", systemImage: "checklist")
                    } description: {
                        Text("Create a reminder for a place that matters.")
                    } actions: {
                        Button("Add Reminder", systemImage: "plus", action: onAdd)
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        if !active.isEmpty { reminderSection("Active", reminders: active) }
                        if !completed.isEmpty { reminderSection("Completed", reminders: completed) }
                        if !archived.isEmpty { reminderSection("Archived", reminders: archived) }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onAdd) { Image(systemName: "plus") }
                }
            }
            .sheet(item: $selected) { ReminderComposerView(reminder: $0) }
        }
    }

    private func reminderSection(_ title: String, reminders: [Reminder]) -> some View {
        Section(title) {
            ForEach(reminders) { reminder in
                HStack(spacing: 12) {
                    Button { selected = reminder } label: {
                        HStack(spacing: 12) {
                        PlaceIcon(category: reminder.category, size: 38)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(reminder.title).foregroundStyle(.white)
                            Text(reminder.placeName)
                                .font(.caption)
                                .foregroundStyle(NearNoteStyle.secondaryText)
                        }
                        Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    Menu {
                        if reminder.isCompleted || reminder.isArchived {
                            Button("Resume", systemImage: "arrow.counterclockwise") { resume(reminder) }
                        } else {
                            Button("Mark as Done", systemImage: "checkmark.circle") { complete(reminder) }
                        }
                        if reminder.isArchived {
                            Button("Restore from Archive", systemImage: "tray.and.arrow.up") { restore(reminder) }
                        } else {
                            Button("Archive", systemImage: "archivebox") { archive(reminder) }
                        }
                        Button("Edit", systemImage: "pencil") { selected = reminder }
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 34, height: 34)
                            .background(NearNoteStyle.raisedSurface, in: Circle())
                    }
                    .accessibilityLabel("Actions for \(reminder.title)")
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if reminder.isCompleted || reminder.isArchived {
                        Button("Resume", systemImage: "arrow.counterclockwise") { resume(reminder) }
                            .tint(.green)
                    } else {
                        Button("Done", systemImage: "checkmark") { complete(reminder) }
                            .tint(.green)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if reminder.isArchived {
                        Button("Restore", systemImage: "tray.and.arrow.up") { restore(reminder) }
                            .tint(NearNoteStyle.accent)
                    } else {
                        Button("Archive", systemImage: "archivebox") { archive(reminder) }
                            .tint(.orange)
                    }
                }
                .contextMenu {
                    if reminder.isCompleted || reminder.isArchived {
                        Button("Resume", systemImage: "arrow.counterclockwise") { resume(reminder) }
                    } else {
                        Button("Mark as Done", systemImage: "checkmark.circle") { complete(reminder) }
                    }
                    if reminder.isArchived {
                        Button("Restore from Archive", systemImage: "tray.and.arrow.up") { restore(reminder) }
                    } else {
                        Button("Archive", systemImage: "archivebox") { archive(reminder) }
                    }
                }
            }
        }
        .listRowBackground(NearNoteStyle.surface)
    }

    private func complete(_ reminder: Reminder) {
        reminder.markDone()
        TelemetryService.shared.track(.reminderCompleted)
        persist(reminder, stopMonitoring: true)
    }

    private func archive(_ reminder: Reminder) {
        reminder.archive()
        TelemetryService.shared.track(.reminderArchived)
        persist(reminder, stopMonitoring: true)
    }

    private func resume(_ reminder: Reminder) {
        reminder.resume()
        TelemetryService.shared.track(.reminderResumed)
        persist(reminder, stopMonitoring: false)
    }

    private func restore(_ reminder: Reminder) {
        reminder.restoreFromArchive()
        persist(reminder, stopMonitoring: false)
    }

    private func persist(_ reminder: Reminder, stopMonitoring: Bool) {
        if stopMonitoring { GeofenceManager.shared.stop(reminder: reminder) }
        try? modelContext.save()
        Task { await LocationService.shared.updateMonitoredRegions() }
    }
}
