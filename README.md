# NearNote

NearNote is a private, location-first iOS reminder app. Its home screen answers “What can I remember around me right now?” by ordering active reminders by distance rather than treating places as another task-list filter.

## Requirements

- Xcode 16 or newer
- iOS 17 or newer
- XcodeGen (`brew install xcodegen`) when regenerating the project
- A physical device for reliable region-monitoring tests

Generate and open the project:

```sh
xcodegen generate
open NearNote.xcodeproj
```

No account, backend, analytics SDK, or API key is required. Apple MapKit is the default place provider.

## Public App Store resources

- Privacy policy: https://joevenner.github.io/nearnotes/privacy/
- Support: https://joevenner.github.io/nearnotes/support/

The static source is in `site/` and `.github/workflows/pages.yml` deploys it to GitHub Pages whenever those files change on `main`.

## Optional Google Places setup

NearNote uses the Places API (New) REST endpoints when `GOOGLE_PLACES_API_KEY` is configured, and automatically falls back to `MKLocalSearch` when the key is absent or a Google request fails.

1. Enable Places API (New) and billing in Google Cloud.
2. Restrict the key to the app and the required Places APIs.
3. Set `GOOGLE_PLACES_API_KEY` in the NearNote target build settings. Do not commit a production key.

The key is expanded into `Info.plist` at build time. Google results store the provider place ID, name, formatted address, coordinate, and detected category. Review Google’s attribution and data-retention requirements before shipping.

Google Maps short links such as `maps.app.goo.gl/...` are expanded on demand using a bounded HTTPS `GET` request. Full Apple Maps, Google Maps, and Waze links are still parsed locally first. A 12-second timeout prevents a slow redirect from blocking the UI.

## Optional diagnostics and feedback setup

NearNote sends nothing by default. To count anonymous installations and basic feature events, set `NEARNOTE_TELEMETRY_ENDPOINT` to an HTTPS endpoint that accepts JSON `POST` requests. Users must also enable **Share Anonymous Usage** in Settings.

Telemetry contains a random installation ID, event name, timestamp, app/build version, iOS version, and non-sensitive event properties. It never contains reminder text, place names, addresses, coordinates, contacts, or advertising identifiers.

Set `NEARNOTE_FEEDBACK_ENDPOINT` to an HTTPS JSON endpoint for direct problem-report delivery. Without it, the Report a Problem screen uses the system share sheet so users can send the report with Mail or another app. Diagnostic attachment is user-controlled and contains only app/build, iOS, and device-model information.

## Permissions

NearNote explains each permission before invoking the system prompt:

- **Notifications** deliver reminder text and Done, Later, Navigate, Complete Here, and Wait for Original Place actions.
- **When In Use Location** orders the home screen by distance and supports map/search flows.
- **Always Location** allows iOS region monitoring to wake the app near a saved place.

The app does not run continuous background GPS. Active high-accuracy location updates run only while a map or reminder composer is visible. Core Location region monitoring handles background arrival events.

## Architecture

The app uses SwiftUI, SwiftData, and small service boundaries:

- `ReminderStore`: on-device SwiftData persistence.
- `LocationService`: foreground/current-location access and permission state.
- `GeofenceManager`: prioritizes the nearest reminders within iOS’s 20-region budget and handles original/similar-place regions.
- `PlaceSearchService`: provider facade with Google-first/Apple-fallback behavior.
- `NotificationService`: local notification categories, actions, quiet-hour scheduling, and snoozes.
- `LinkParserService`: offline parsing for full Apple Maps, Google Maps, and Waze links.
- `LinkResolverService`: bounded online expansion for shortened Google Maps links.
- `SettingsStore`: radius mode, quiet hours, cooldown, recent places, Home, and Work.
- `TelemetryService` / `FeedbackService`: opt-in anonymous events and user-initiated reports with no location content.

`Reminder` stores a provider-independent place snapshot: name, address, latitude, longitude, provider, provider place ID, category, and confidence. Smart alternatives remain opt-in per reminder and can be disabled permanently with “Wait for original place.”

## V1 behavior

- Location-first home with reminders sorted by current distance.
- Fast composer supporting search, map center, full map links, recent places, Home, and Work.
- High-confidence category suggestions for pharmacies, supermarkets, fuel, ATMs, cafés, restaurants, malls, hospitals, offices, and related types.
- Exact-place and similar-category trigger modes.
- Automatic, 100 m, 250 m, 500 m, 1000 m, and custom radius choices.
- Local actionable notifications with a configurable repeat cooldown and quiet hours.
- Done, resume, archive, and restore reminder lifecycle actions.
- Unlimited labeled saved places, with the first two shown until expanded.
- Saved places can be added by normal search or by pasting full and shortened Google Maps, Apple Maps, and Waze links.
- Privacy/permission education and an in-app trust screen.
- Professional Pebble states and app-icon direction in `Assets.xcassets`.

## Visual system

The shipping UI is intentionally dark and location-led: a navy-black canvas, layered graphite surfaces, SF typography, electric blue reserved for interactive emphasis, and semantic category colors for places. The main navigation mirrors the product hierarchy: Nearby, Map, Reminders, and Settings.

`Assets.xcassets` includes cinematic onboarding scenes plus transparent idle, searching, empty, and completed Pebble states. Their generation prompts and integration notes are documented in `Docs/AssetGeneration.md`.

## Testing

Run unit tests from Xcode or:

```sh
xcodebuild test -project NearNote.xcodeproj -scheme NearNote -destination 'platform=iOS Simulator,name=iPhone 16'
```

Unit coverage includes persistence, category detection, full map-link parsing, and shortened-link fallback. On a physical device, verify:

1. foreground map/search location behavior;
2. Always Location and notification permission education;
3. arrival delivery with the app backgrounded and terminated;
4. cooldown and quiet-hour behavior;
5. Done, Later, Navigate, Complete Here, and Wait for Original Place actions;
6. the 20-region prioritization with more than 20 active reminders.

## Implemented, mocked, and remaining

Implemented: local persistence, polished location-first UI, provider abstraction/fallback, Google Places API (New) text and nearby REST clients, MapKit rendering, offline full-link parsing, recent/Home/Work places, category confidence, smart alternatives, geofences, local notification actions, quiet hours, cooldown, radius presets, privacy education, and generated cinematic brand assets.

Mock/fallback behavior: Apple MapKit is the zero-configuration provider. A missing or failing Google key falls back automatically. Shortened Google Maps URLs use a time-limited redirect request; if Google or the network does not return usable coordinates, the UI offers a clean retry/manual-search fallback. Telemetry and direct feedback remain disabled until their endpoints are configured.

Remaining before App Store release: select the Apple Developer signing team, archive with a complete local Xcode installation, run notification/geofence scenarios on physical devices, and complete App Store Connect metadata. Optional telemetry remains disabled unless a production endpoint is configured and the user opts in. No backend, login, subscriptions, advertising, AI chat, family sharing, CarPlay, or Watch app is included. See `Docs/ReleaseChecklist.md`.
