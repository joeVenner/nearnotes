import SwiftUI
import CoreLocation
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var notificationService: NotificationService
    @StateObject private var settings = SettingsStore.shared
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedPlace.sortOrder) private var allSavedPlaces: [SavedPlace]
    @State private var showPermissions = false
    @State private var showAddSavedPlace = false
    @State private var editingSavedPlace: SavedPlace?
    @State private var showAllSavedPlaces = false

    private var savedPlaces: [SavedPlace] {
        allSavedPlaces.filter { $0.type != .recent }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { showPermissions = true } label: {
                        SettingsRow(
                            symbol: "bell.badge.fill",
                            title: "Location & Notifications",
                            value: permissionSummary
                        )
                    }
                    .foregroundStyle(.primary)

                    Picker("Default radius", selection: Binding(
                        get: { settings.radiusMode },
                        set: { settings.radiusMode = $0 }
                    )) {
                        ForEach(RadiusMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    if settings.radiusMode == .custom {
                        VStack(alignment: .leading, spacing: 12) {
                            LabeledContent("Custom radius", value: customRadiusLabel)
                            Slider(value: $settings.customRadius, in: 50...2_000, step: 50)
                        }
                        .padding(.vertical, 6)
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("The default radius is used for new reminders. You can change it before saving.")
                }

                Section {
                    Toggle("Quiet Hours", isOn: $settings.quietHoursEnabled)
                    if settings.quietHoursEnabled {
                        DatePicker("From", selection: timeBinding(for: true), displayedComponents: .hourAndMinute)
                        DatePicker("Until", selection: timeBinding(for: false), displayedComponents: .hourAndMinute)
                    }
                    Picker("Repeat alerts", selection: $settings.cooldownMinutes) {
                        Text("After 15 minutes").tag(15)
                        Text("After 30 minutes").tag(30)
                        Text("After 1 hour").tag(60)
                    }
                } header: {
                    Text("Notifications")
                }

                Section("Saved Places") {
                    ForEach(Array(savedPlaces.prefix(2))) { place in
                        savedPlaceRow(place)
                    }

                    if savedPlaces.count > 2 {
                        DisclosureGroup(isExpanded: $showAllSavedPlaces) {
                            ForEach(Array(savedPlaces.dropFirst(2))) { place in
                                savedPlaceRow(place)
                            }
                        } label: {
                            Text(showAllSavedPlaces ? "Show fewer" : "Show \(savedPlaces.count - 2) more")
                                .font(.subheadline.weight(.medium))
                        }
                    }

                    Button { showAddSavedPlace = true } label: {
                        Label("Add Saved Place", systemImage: "plus.circle.fill")
                    }
                }

                Section {
                    Toggle("Share Anonymous Usage", isOn: $settings.shareAnonymousUsage)
                        .disabled(!TelemetryService.shared.isConfigured)
                    if !TelemetryService.shared.isConfigured {
                        Label("Usage collection is not configured in this build.", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    NavigationLink {
                        PrivacyView()
                    } label: {
                        SettingsRow(
                            symbol: "lock.shield.fill",
                            title: "Privacy",
                            value: "Private iCloud"
                        )
                    }
                    if let privacyURL = AppConfiguration.privacyPolicyURL {
                        Link(destination: privacyURL) {
                            SettingsRow(symbol: "safari.fill", title: "Privacy Policy", value: "Web")
                        }
                    }
                } header: {
                    Text("Privacy & Diagnostics")
                } footer: {
                    Text("Optional usage data never includes reminder text, saved places, or coordinates. No diagnostic data is sent unless an endpoint is configured.")
                }

                Section("Support") {
                    NavigationLink {
                        FeedbackView()
                    } label: {
                        SettingsRow(symbol: "exclamationmark.bubble.fill", title: "Report a Problem", value: "")
                    }
                    if let supportURL = AppConfiguration.supportURL {
                        Link(destination: supportURL) {
                            SettingsRow(symbol: "questionmark.circle.fill", title: "Support Website", value: "Web")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(NearNoteBackground())
            .tint(NearNoteStyle.accent)
            .navigationTitle("Settings")
            .sheet(isPresented: $showPermissions) { PermissionEducationView() }
            .sheet(isPresented: $showAddSavedPlace) {
                SavedPlaceEditor(existing: nil, nextSortOrder: savedPlaces.count)
            }
            .sheet(item: $editingSavedPlace) {
                SavedPlaceEditor(existing: $0, nextSortOrder: savedPlaces.count)
            }
            .task { migrateLegacySavedPlacesIfNeeded() }
        }
    }

    private func migrateLegacySavedPlacesIfNeeded() {
        let labels = Set(savedPlaces.map { $0.displayLabel.lowercased() })
        if let home = settings.homePlace, !labels.contains("home") {
            modelContext.insert(SavedPlace(
                name: home.name,
                address: home.address,
                latitude: home.latitude,
                longitude: home.longitude,
                type: .custom,
                label: "Home",
                symbolName: "house.fill",
                sortOrder: savedPlaces.count
            ))
        }
        if let work = settings.workPlace, !labels.contains("work") {
            modelContext.insert(SavedPlace(
                name: work.name,
                address: work.address,
                latitude: work.latitude,
                longitude: work.longitude,
                type: .custom,
                label: "Work",
                symbolName: "briefcase.fill",
                sortOrder: savedPlaces.count + 1
            ))
        }
        try? modelContext.save()
    }

    private func savedPlaceRow(_ place: SavedPlace) -> some View {
        Button { editingSavedPlace = place } label: {
            SettingsRow(symbol: place.symbolName, title: place.displayLabel, value: place.name)
        }
        .foregroundStyle(.primary)
        .swipeActions {
            Button("Delete", systemImage: "trash", role: .destructive) {
                modelContext.delete(place)
                try? modelContext.save()
            }
        }
    }

    private var permissionSummary: String {
        notificationService.isAuthorized && locationService.authorizationStatus == .authorizedAlways ? "Ready" : "Review"
    }

    private var customRadiusLabel: String {
        settings.customRadius >= 1_000
            ? String(format: "%.1f km", settings.customRadius / 1_000)
            : "\(Int(settings.customRadius))m"
    }

    private func timeBinding(for start: Bool) -> Binding<Date> {
        Binding {
            let minutes = start ? settings.quietHoursStartMinutes : settings.quietHoursEndMinutes
            return Calendar.current.date(
                bySettingHour: minutes / 60,
                minute: minutes % 60,
                second: 0,
                of: Date()
            ) ?? Date()
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            let value = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            if start {
                settings.quietHoursStartMinutes = value
            } else {
                settings.quietHoursEndMinutes = value
            }
        }
    }
}

private struct SettingsRow: View {
    let symbol: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct PrivacyView: View {
    private let promises = [
        ("location.slash.fill", "No location history", "NearNotes never builds a timeline of where you’ve been."),
        ("icloud.fill", "Private iCloud sync", "Reminders and saved places are stored locally and synced through your private iCloud database when available."),
        ("battery.100percent", "Battery-efficient by design", "Apple region monitoring wakes NearNotes only when needed."),
        ("hand.raised.fill", "Optional anonymous diagnostics", "Usage sharing is off by default and never includes your reminder text or coordinates.")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 54, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.top, 34)
                Text("Your places stay yours")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                Text("NearNotes needs no separate account and operates no reminder server. Apple CloudKit privately syncs your data across your devices.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                    .padding(.horizontal, 12)

                VStack(spacing: 24) {
                    ForEach(promises, id: \.1) { promise in
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: promise.0)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(promise.1)
                                    .font(.headline)
                                Text(promise.2)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.top, 38)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(NearNoteBackground())
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SavedPlaceEditor: View {
    let existing: SavedPlace?
    let nextSortOrder: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var locationService: LocationService
    @StateObject private var service = PlaceSearchService()
    @StateObject private var linkResolver = LinkResolverService()
    @State private var label: String
    @State private var icon: SavedPlaceIcon
    @State private var selectedPlace: Place?
    @State private var query: String = ""
    @State private var isResolvingLink = false
    @State private var linkError: String?
    @State private var resolveTask: Task<Void, Never>?

    init(existing: SavedPlace?, nextSortOrder: Int) {
        self.existing = existing
        self.nextSortOrder = nextSortOrder
        _label = State(initialValue: existing?.displayLabel ?? "")
        _icon = State(initialValue: SavedPlaceIcon(rawValue: existing?.symbolName ?? "") ?? .pin)
        _selectedPlace = State(initialValue: existing?.asPlace)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Label") {
                    TextField("Home, Gym, Parents…", text: $label)
                    Picker("Icon", selection: $icon) {
                        ForEach(SavedPlaceIcon.allCases) { option in
                            Label(option.title, systemImage: option.rawValue).tag(option)
                        }
                    }
                }

                Section {
                    if let selectedPlace {
                        PlaceResultRowForSettings(place: selectedPlace)
                        Button("Choose a Different Place") {
                            self.selectedPlace = nil
                            query = ""
                            linkError = nil
                        }
                    } else {
                        TextField("Search or paste a map link", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if isResolvingLink {
                            ProgressView("Opening map link…")
                        } else if service.isSearching {
                            ProgressView("Searching…")
                        }
                        if let linkError {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Couldn’t open this link", systemImage: "exclamationmark.triangle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.orange)
                                Text(linkError)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        } else if !isResolvingLink {
                            ForEach(service.results) { place in
                                Button { selectedPlace = place } label: {
                                    PlaceResultRowForSettings(place: place)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } header: {
                    Text("Place")
                } footer: {
                    Text("Search normally, or paste a full or shortened Google Maps, Apple Maps, or Waze link.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(NearNoteBackground())
            .navigationTitle(existing == nil ? "Add Saved Place" : "Edit Saved Place")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: query) { _, value in
                handleQuery(value)
            }
            .onDisappear { resolveTask?.cancel() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedPlace == nil)
                }
            }
        }
    }

    private func handleQuery(_ value: String) {
        resolveTask?.cancel()
        linkError = nil
        guard let url = LinkResolverService.extractURL(from: value) else {
            isResolvingLink = false
            service.search(query: value, near: locationService.currentLocation?.coordinate)
            return
        }

        isResolvingLink = true
        service.search(query: "", near: nil)
        resolveTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(250))
                let place = try await linkResolver.resolvePlace(url: url)
                try Task.checkCancellation()
                selectedPlace = place
                isResolvingLink = false
                TelemetryService.shared.track(.mapLinkResolved, properties: ["provider": url.host ?? "unknown"])
            } catch is CancellationError {
                return
            } catch {
                isResolvingLink = false
                linkError = (error as? LocalizedError)?.errorDescription
                    ?? "Try again or search for the place manually."
                TelemetryService.shared.track(.mapLinkFailed, properties: ["provider": url.host ?? "unknown"])
            }
        }
    }

    private func save() {
        guard let selectedPlace else { return }
        let value = existing ?? SavedPlace(
            name: selectedPlace.name,
            address: selectedPlace.address,
            latitude: selectedPlace.latitude,
            longitude: selectedPlace.longitude,
            type: .custom,
            label: label,
            symbolName: icon.rawValue,
            sortOrder: nextSortOrder
        )
        value.label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        value.name = selectedPlace.name
        value.address = selectedPlace.address
        value.latitude = selectedPlace.latitude
        value.longitude = selectedPlace.longitude
        value.type = .custom
        value.symbolName = icon.rawValue
        if existing == nil { modelContext.insert(value) }
        try? modelContext.save()
        dismiss()
    }
}

private enum SavedPlaceIcon: String, CaseIterable, Identifiable {
    case home = "house.fill"
    case work = "briefcase.fill"
    case gym = "dumbbell.fill"
    case school = "graduationcap.fill"
    case family = "person.2.fill"
    case favorite = "heart.fill"
    case pin = "mappin.circle.fill"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .home: "Home"
        case .work: "Work"
        case .gym: "Gym"
        case .school: "School"
        case .family: "Family"
        case .favorite: "Favorite"
        case .pin: "Place"
        }
    }
}

private struct PlaceResultRowForSettings: View {
    let place: Place

    var body: some View {
        HStack(spacing: 12) {
            PlaceIcon(category: place.category)
            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(.body.weight(.medium))
                Text(place.address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 5)
    }
}

private struct FeedbackView: View {
    @StateObject private var settings = SettingsStore.shared
    @State private var message = ""
    @State private var contactEmail = ""
    @State private var isSubmitting = false
    @State private var submitted = false
    @State private var errorMessage: String?
    private let service = FeedbackService()

    var body: some View {
        Form {
            Section {
                TextField("What isn’t working properly?", text: $message, axis: .vertical)
                    .lineLimit(5...10)
                TextField("Email for a reply (optional)", text: $contactEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Problem")
            } footer: {
                Text("Do not include passwords or sensitive personal information.")
            }

            Section("Report Details") {
                Toggle("Include App Diagnostics", isOn: $settings.includeDiagnosticsInReports)
                if settings.includeDiagnosticsInReports {
                    Text("Includes app version, build, iOS version, and device model. It never includes reminders, places, or coordinates.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                if service.isConfigured {
                    Button(action: submit) {
                        if isSubmitting { ProgressView().frame(maxWidth: .infinity) }
                        else { Text("Send Report").frame(maxWidth: .infinity) }
                    }
                    .disabled(isSubmitting || cleanMessage.isEmpty)
                }

                ShareLink(item: service.shareText(
                    message: cleanMessage,
                    contactEmail: contactEmail,
                    includeDiagnostics: settings.includeDiagnosticsInReports
                )) {
                    Label(service.isConfigured ? "Share a Copy" : "Share Report", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .disabled(cleanMessage.isEmpty)
            } footer: {
                if !service.isConfigured {
                    Text("Direct delivery is not configured, so iOS will let you share the report using Mail or another app.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(NearNoteBackground())
        .navigationTitle("Report a Problem")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Report Sent", isPresented: $submitted) {
            Button("Done") { message = "" }
        } message: {
            Text("Thank you. The report was delivered without reminder or location data.")
        }
        .alert("Couldn’t Send Report", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Try sharing the report instead.")
        }
    }

    private var cleanMessage: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func submit() {
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                try await service.submit(
                    message: cleanMessage,
                    contactEmail: contactEmail.isEmpty ? nil : contactEmail,
                    includeDiagnostics: settings.includeDiagnosticsInReports
                )
                TelemetryService.shared.track(.feedbackSubmitted)
                submitted = true
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Try sharing the report instead."
            }
        }
    }
}
