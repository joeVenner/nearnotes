import SwiftUI
import SwiftData

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var locationService: LocationService
    @StateObject private var searchService = PlaceSearchService()
    @StateObject private var linkResolver = LinkResolverService()
    @State private var query = ""
    @State private var isResolvingLink = false
    @State private var linkError: LinkResolverError?
    @State private var showAllSavedPlaces = false

    @Query(filter: #Predicate<SavedPlace> { $0.typeRaw == "recent" }, sort: \SavedPlace.lastUsedAt, order: .reverse)
    private var recentPlaces: [SavedPlace]
    @Query(sort: \SavedPlace.sortOrder) private var allSavedPlaces: [SavedPlace]

    private var savedPlaces: [SavedPlace] { allSavedPlaces.filter { $0.type != .recent } }

    let onPlaceSelected: (Place) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                NearNoteBackground()
                List {
                    if query.isEmpty { savedContent }
                    if isResolvingLink {
                        HStack(spacing: 14) {
                            Image("pebble_searching")
                                .resizable().scaledToFit().frame(width: 58, height: 58)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Opening map link…").font(.headline)
                                Text("Finding the exact place")
                                    .font(.caption).foregroundStyle(NearNoteStyle.secondaryText)
                            }
                        }
                    } else if !query.isEmpty {
                        ForEach(searchService.results) { place in
                            Button { select(place) } label: { PlacePickerRow(place: place) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listRowBackground(NearNoteStyle.surface)
            }
            .navigationTitle("Choose a place")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search or paste a map link")
            .onChange(of: query) { _, value in handle(value) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Can’t open this link", isPresented: Binding(
                get: { linkError != nil },
                set: { if !$0 { linkError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(linkError?.errorDescription ?? "Search for the place instead.")
            }
        }
        .tint(NearNoteStyle.accent)
    }

    @ViewBuilder private var savedContent: some View {
        if !savedPlaces.isEmpty {
            Section("Saved") {
                ForEach(Array(savedPlaces.prefix(2))) { place in savedButton(place) }
                if savedPlaces.count > 2 {
                    DisclosureGroup(isExpanded: $showAllSavedPlaces) {
                        ForEach(Array(savedPlaces.dropFirst(2))) { place in savedButton(place) }
                    } label: {
                        Text(showAllSavedPlaces ? "Show fewer" : "Show \(savedPlaces.count - 2) more")
                    }
                }
            }
        }
        if !recentPlaces.isEmpty {
            Section("Recent") {
                ForEach(recentPlaces.prefix(6)) { place in
                    Button { select(place.asPlace) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(NearNoteStyle.secondaryText)
                                .frame(width: 34, height: 34)
                                .background(NearNoteStyle.raisedSurface, in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name).foregroundStyle(.white)
                                Text(place.address).font(.caption).foregroundStyle(NearNoteStyle.secondaryText).lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        } else if savedPlaces.isEmpty {
            Section {
                VStack(spacing: 10) {
                    Image("pebble_searching")
                        .resizable().scaledToFit().frame(width: 145, height: 120)
                    Text("Find somewhere that matters").font(.headline)
                    Text("Search for a business, address, or paste an Apple Maps, Google Maps, or Waze link.")
                        .font(.subheadline)
                        .foregroundStyle(NearNoteStyle.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .listRowBackground(Color.clear)
            }
        }
    }

    private func savedButton(_ place: SavedPlace) -> some View {
        Button { select(place.asPlace) } label: {
            HStack(spacing: 12) {
                Image(systemName: place.symbolName)
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(NearNoteStyle.raisedSurface, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.displayLabel).foregroundStyle(.white)
                    Text(place.name).font(.caption).foregroundStyle(NearNoteStyle.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func handle(_ value: String) {
        linkError = nil
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let url = LinkResolverService.extractURL(from: value) {
            isResolvingLink = true
            Task {
                defer { isResolvingLink = false }
                do {
                    select(try await linkResolver.resolvePlace(url: url))
                    TelemetryService.shared.track(.mapLinkResolved, properties: ["provider": url.host ?? "unknown"])
                }
                catch let error as LinkResolverError {
                    TelemetryService.shared.track(.mapLinkFailed, properties: ["provider": url.host ?? "unknown"])
                    linkError = error
                }
                catch {
                    TelemetryService.shared.track(.mapLinkFailed, properties: ["provider": url.host ?? "unknown"])
                    linkError = .unableToResolve
                }
            }
        } else {
            searchService.search(query: value, near: locationService.currentLocation?.coordinate)
        }
    }

    private func select(_ place: Place) {
        modelContext.insert(SavedPlace(
            name: place.name,
            address: place.address,
            latitude: place.latitude,
            longitude: place.longitude,
            type: .recent
        ))
        try? modelContext.save()
        onPlaceSelected(place)
        dismiss()
    }
}

private struct PlacePickerRow: View {
    let place: Place
    var body: some View {
        HStack(spacing: 12) {
            PlaceIcon(category: place.category, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(place.name).font(.body.weight(.medium)).foregroundStyle(.white)
                if !place.address.isEmpty {
                    Text(place.address).font(.caption).foregroundStyle(NearNoteStyle.secondaryText).lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
