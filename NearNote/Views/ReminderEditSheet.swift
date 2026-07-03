import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct ReminderEditSheet: View {
    let reminder: Reminder
    var body: some View { ReminderComposerView(reminder: reminder) }
}

struct ReminderComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var locationService: LocationService
    @StateObject private var searchService = PlaceSearchService()
    @StateObject private var settings = SettingsStore.shared
    @FocusState private var titleFocused: Bool

    private let reminder: Reminder?
    @State private var title: String
    @State private var selectedPlace: Place?
    @State private var triggerMode: ReminderTriggerMode
    @State private var radiusMode: RadiusMode
    @State private var customRadius: Double
    @State private var isOneTime: Bool
    @State private var triggerOnArrival: Bool
    @State private var hasTimeConstraints: Bool
    @State private var startTime: Date
    @State private var endTime: Date

    init(reminder: Reminder? = nil, initialPlace: Place? = nil) {
        self.reminder = reminder
        _title = State(initialValue: reminder?.title ?? "")

        if let reminder {
            _selectedPlace = State(initialValue: Place(
                name: reminder.placeName,
                address: reminder.placeAddress,
                latitude: reminder.latitude,
                longitude: reminder.longitude,
                provider: PlaceProvider(rawValue: reminder.placeProvider) ?? .apple,
                providerPlaceID: reminder.providerPlaceID,
                category: reminder.category,
                categoryConfidence: reminder.categoryConfidence
            ))
            _triggerMode = State(initialValue: reminder.triggerMode)
            _radiusMode = State(initialValue: RadiusMode.closest(to: reminder.radius))
            _customRadius = State(initialValue: reminder.radius)
            _isOneTime = State(initialValue: reminder.isOneTime)
            _triggerOnArrival = State(initialValue: reminder.triggerOnArrival)
            _hasTimeConstraints = State(initialValue: reminder.startTime != nil)
            _startTime = State(initialValue: reminder.startTime ?? Date())
            _endTime = State(initialValue: reminder.endTime ?? Date().addingTimeInterval(3600))
        } else {
            let settings = SettingsStore.shared
            _selectedPlace = State(initialValue: initialPlace)
            _triggerMode = State(initialValue: .specificPlace)
            _radiusMode = State(initialValue: settings.radiusMode)
            _customRadius = State(initialValue: settings.customRadius)
            _isOneTime = State(initialValue: true)
            _triggerOnArrival = State(initialValue: true)
            _hasTimeConstraints = State(initialValue: false)
            _startTime = State(initialValue: Date())
            _endTime = State(initialValue: Date().addingTimeInterval(3600))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What do you want to remember?", text: $title, axis: .vertical)
                        .font(.title2.weight(.semibold))
                        .lineLimit(2...4)
                        .focused($titleFocused)
                        .submitLabel(.next)
                        .padding(.vertical, 8)
                } header: {
                    Text("Reminder")
                }

                placeSection

                if let place = selectedPlace {
                    triggerSection(for: place)
                    radiusSection
                    timeSection
                    repeatSection
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(NearNoteBackground())
            .tint(NearNoteStyle.accent)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(reminder == nil ? "New Reminder" : "Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(NearNoteStyle.canvas.opacity(0.94), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if reminder == nil { titleFocused = true }
                locationService.startInUseTracking()
            }
            .onDisappear { locationService.stopInUseTracking() }
        }
    }

    @ViewBuilder private var placeSection: some View {
        Section {
            if let place = selectedPlace {
                SelectedPlaceRow(place: place)
                Button("Choose a different place") {
                    withAnimation { selectedPlace = nil }
                }
            } else {
                NavigationLink {
                    PlaceSearchPickerView(service: searchService, onSelect: choose)
                } label: {
                    ComposerDestinationRow(
                        symbol: "magnifyingglass",
                        title: "Search for a place",
                        subtitle: "Businesses, landmarks, and addresses"
                    )
                }

                NavigationLink {
                    MapPlacePickerView(onSelect: choose)
                } label: {
                    ComposerDestinationRow(
                        symbol: "map",
                        title: "Choose on map",
                        subtitle: "Drop a pin anywhere"
                    )
                }

                NavigationLink {
                    LinkPlacePickerView(onSelect: choose)
                } label: {
                    ComposerDestinationRow(
                        symbol: "link",
                        title: "Paste a map link",
                        subtitle: "Apple Maps, Google Maps, or Waze"
                    )
                }

                NavigationLink {
                    SavedPlacePickerView(onSelect: choose)
                } label: {
                    ComposerDestinationRow(
                        symbol: "clock.arrow.circlepath",
                        title: "Recent and saved places",
                        subtitle: "Home, work, and places you’ve used"
                    )
                }
            }
        } header: {
            Text("Place")
        } footer: {
            if selectedPlace == nil {
                Text("Choose where this reminder should appear.")
            }
        }
    }

    private func triggerSection(for place: Place) -> some View {
        Section {
            Picker("When", selection: $triggerOnArrival) {
                Text("Arriving").tag(true)
                Text("Leaving").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 4)

            Picker("Notify me", selection: $triggerMode) {
                Text("Only at this place").tag(ReminderTriggerMode.specificPlace)
                if place.category != nil {
                    Text("At any similar place").tag(ReminderTriggerMode.similarCategory)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Notify me")
        } footer: {
            if triggerMode == .similarCategory, let category = place.category {
                Text("NearNote can also remind you at another nearby \(category.title.lowercased()).")
            } else {
                Text("This reminder will only appear near \(place.name).")
            }
        }
    }

    private var radiusSection: some View {
        Section {
            Picker("Distance", selection: $radiusMode) {
                ForEach(RadiusMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            if radiusMode == .custom {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent("Custom distance", value: customRadiusLabel)
                    Slider(value: $customRadius, in: 50...2_000, step: 50)
                        .tint(NearNoteStyle.accent)
                }
                .padding(.vertical, 6)
            }
        } header: {
            Text("Arrival radius")
        } footer: {
            Text(radiusMode == .automatic
                 ? "Automatic uses a reliable distance for this location while keeping battery use low."
                 : "NearNote uses Apple’s battery-efficient region monitoring, not continuous tracking.")
        }
    }

    private var repeatSection: some View {
        Section {
            Picker("Repeat", selection: $isOneTime) {
                Text("One Time").tag(true)
                Text("Recurring").tag(false)
            }
        } footer: {
            Text(isOneTime
                 ? "Completing this reminder moves it to Done."
                 : "After completing a recurring reminder, you can resume it from the Reminders tab.")
        }
    }

    private var timeSection: some View {
        Section {
            Toggle("Time constraints", isOn: $hasTimeConstraints)
            
            if hasTimeConstraints {
                DatePicker("Start time", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("End time", selection: $endTime, displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("Time Window")
        } footer: {
            Text(hasTimeConstraints ? "The reminder will only trigger between these times." : "The reminder will trigger at any time of day.")
        }
    }

    private var customRadiusLabel: String {
        customRadius >= 1_000 ? String(format: "%.1f km", customRadius / 1_000) : "\(Int(customRadius))m"
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedPlace != nil
    }

    private func choose(_ place: Place) {
        selectedPlace = place
        triggerMode = place.category != nil && place.categoryConfidence >= 0.9 ? .similarCategory : .specificPlace
    }

    private func save() {
        guard let place = selectedPlace else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = reminder ?? Reminder(
            title: cleanTitle,
            latitude: place.latitude,
            longitude: place.longitude,
            placeName: place.name
        )

        value.title = cleanTitle
        value.placeName = place.name
        value.placeAddress = place.address
        value.latitude = place.latitude
        value.longitude = place.longitude
        value.placeProvider = place.provider.rawValue
        value.providerPlaceID = place.providerPlaceID
        value.category = place.category
        value.categoryConfidence = place.categoryConfidence
        value.triggerMode = place.category == nil ? .specificPlace : triggerMode
        value.alternativesDisabled = false
        value.radius = radiusMode.radius(customRadius: customRadius)
        value.triggerOnArrival = triggerOnArrival
        value.isOneTime = isOneTime
        value.isEnabled = true
        value.isCompleted = false
        value.isArchived = false
        
        if hasTimeConstraints {
            value.startTime = startTime
            value.endTime = endTime
        } else {
            value.startTime = nil
            value.endTime = nil
        }

        if reminder == nil {
            modelContext.insert(value)
            TelemetryService.shared.track(.reminderCreated, properties: ["trigger": value.triggerModeRaw])
        }
        if radiusMode == .custom { settings.customRadius = customRadius }
        try? modelContext.save()
        settings.remember(place)
        Task { await locationService.updateMonitoredRegions() }
        dismiss()
    }
}

private struct ComposerDestinationRow: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(NearNoteStyle.raisedSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.vertical, 5)
    }
}

private struct SelectedPlaceRow: View {
    let place: Place

    var body: some View {
        HStack(spacing: 13) {
            PlaceIcon(category: place.category)
            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(.headline)
                if !place.address.isEmpty {
                    Text(place.address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PlaceSearchPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationService: LocationService
    @ObservedObject var service: PlaceSearchService
    let onSelect: (Place) -> Void
    @State private var query = ""

    var body: some View {
        List {
            if service.isSearching {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Searching nearby…")
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(service.results) { place in
                Button {
                    onSelect(place)
                    dismiss()
                } label: {
                    PlaceResultRow(place: place)
                }
                .buttonStyle(.plain)
            }
            if let error = service.errorMessage, !query.isEmpty {
                ContentUnavailableView("Search unavailable", systemImage: "magnifyingglass", description: Text(error))
            }
        }
        .navigationTitle("Search Places")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Place or address")
        .onChange(of: query) { _, value in
            service.search(query: value, near: locationService.currentLocation?.coordinate)
        }
    }
}

private struct PlaceResultRow: View {
    let place: Place

    var body: some View {
        HStack(spacing: 12) {
            PlaceIcon(category: place.category)
            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(.body.weight(.medium))
                if !place.address.isEmpty {
                    Text(place.address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 5)
    }
}

private struct MapPlacePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationService: LocationService
    let onSelect: (Place) -> Void
    @State private var position: MapCameraPosition = .automatic
    @State private var isResolving = false

    var body: some View {
        GeometryReader { geometry in
            MapReader { proxy in
                Map(position: $position) { UserAnnotation() }
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                    }
                    .overlay {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(NearNoteStyle.accent)
                            .offset(y: -19)
                            .allowsHitTesting(false)
                    }
                    .safeAreaInset(edge: .bottom) {
                        Button {
                            guard let coordinate = proxy.convert(
                                CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2),
                                from: .local
                            ) else { return }
                            resolve(coordinate)
                        } label: {
                            if isResolving {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Text("Use This Location").frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isResolving)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                    }
            }
        }
        .navigationTitle("Choose on Map")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let coordinate = locationService.currentLocation?.coordinate {
                position = .region(MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: 1_200,
                    longitudinalMeters: 1_200
                ))
            }
        }
    }

    private func resolve(_ coordinate: CLLocationCoordinate2D) {
        isResolving = true
        Task {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let placemark = (try? await CLGeocoder().reverseGeocodeLocation(location))?.first
            let detected = PlaceCategory.detect(from: [
                placemark?.name ?? "",
                placemark?.areasOfInterest?.joined(separator: " ") ?? ""
            ])
            let place = Place(
                name: placemark?.areasOfInterest?.first ?? placemark?.name ?? "Dropped Pin",
                address: [placemark?.thoroughfare, placemark?.locality].compactMap { $0 }.joined(separator: ", "),
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                provider: .manual,
                category: detected.category,
                categoryConfidence: detected.confidence
            )
            onSelect(place)
            dismiss()
        }
    }
}

private struct LinkPlacePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (Place) -> Void
    @StateObject private var resolver = LinkResolverService()
    @State private var link = ""
    @State private var message: String?
    @State private var isResolving = false

    var body: some View {
        Form {
            Section {
                TextField("Paste map link", text: $link, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .lineLimit(3...6)
            } footer: {
                Text("NearNote reads full Apple Maps, Google Maps, and Waze links on your device.")
            }

            Section {
                Button(action: parse) {
                    if isResolving {
                        HStack { ProgressView(); Text("Opening Link…") }
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Use This Link").frame(maxWidth: .infinity)
                    }
                }
                .fontWeight(.semibold)
                .disabled(isResolving || link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Paste a Map Link")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Can’t Read This Link", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(message ?? "")
        }
    }

    private func parse() {
        switch LinkParserService().parse(link) {
        case .place(let place):
            onSelect(place)
            dismiss()
        case .needsExpandedLink:
            resolveOnline()
        case .unsupported:
            if LinkResolverService.extractURL(from: link) != nil {
                resolveOnline()
            } else {
                message = "No location was found. Paste a valid Apple Maps, Google Maps, or Waze link."
            }
        }
    }

    private func resolveOnline() {
        guard let url = LinkResolverService.extractURL(from: link) else {
            message = "No valid link was found."
            return
        }
        isResolving = true
        Task {
            defer { isResolving = false }
            do {
                onSelect(try await resolver.resolvePlace(url: url))
                TelemetryService.shared.track(.mapLinkResolved, properties: ["provider": url.host ?? "unknown"])
                dismiss()
            } catch {
                TelemetryService.shared.track(.mapLinkFailed, properties: ["provider": url.host ?? "unknown"])
                message = (error as? LocalizedError)?.errorDescription
                    ?? "This link could not be opened. Try again or search for the place manually."
            }
        }
    }
}

private struct SavedPlacePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = SettingsStore.shared
    @Query(sort: \SavedPlace.sortOrder) private var storedPlaces: [SavedPlace]
    let onSelect: (Place) -> Void

    private var places: [(label: String, place: Place)] {
        var values: [(label: String, place: Place)] = storedPlaces
            .filter { $0.type != .recent }
            .map { (label: $0.displayLabel, place: $0.asPlace) }
        if let home = settings.homePlace, !values.contains(where: { $0.label.caseInsensitiveCompare("Home") == .orderedSame }) {
            values.insert(("Home", home), at: 0)
        }
        if let work = settings.workPlace, !values.contains(where: { $0.label.caseInsensitiveCompare("Work") == .orderedSame }) {
            values.insert(("Work", work), at: min(1, values.count))
        }
        values.append(contentsOf: settings.recentPlaces.map { ($0.name, $0) })
        return values
    }

    var body: some View {
        List {
            if places.isEmpty {
                ContentUnavailableView(
                    "No Saved Places",
                    systemImage: "mappin.slash",
                    description: Text("Places you use will appear here.")
                )
            } else {
                ForEach(Array(places.enumerated()), id: \.offset) { _, item in
                    Button {
                        onSelect(item.place)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            PlaceIcon(category: item.place.category)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.label).font(.body.weight(.medium))
                                if item.label != item.place.name {
                                    Text(item.place.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Saved Places")
        .navigationBarTitleDisplayMode(.inline)
    }
}
