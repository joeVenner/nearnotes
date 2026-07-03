import SwiftUI
import CoreLocation
import UIKit

struct PermissionEducationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var notificationService: NotificationService

    var body: some View {
        NavigationStack {
        List {
                Section {
                    VStack(spacing: 12) {
                        Image("pebble_idle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 132, height: 132)
                            .accessibilityHidden(true)
                        Text("Alerts that respect your battery")
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                        Text("NearNote asks only for access needed to show your reminders at the right place.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 18, leading: 20, bottom: 22, trailing: 20))
                }

                Section("Access") {
                    PermissionRow(
                        symbol: "bell.fill",
                        title: "Notifications",
                        detail: "Shows your reminder with Done, Later, and Directions actions.",
                        isReady: notificationService.isAuthorized,
                        actionTitle: "Allow Notifications"
                    ) {
                        notificationService.requestPermission()
                    }

                    PermissionRow(
                        symbol: "location.fill",
                        title: "Location While Using",
                        detail: "Sorts nearby reminders and helps you choose places.",
                        isReady: hasForegroundLocation,
                        actionTitle: "Allow Location"
                    ) {
                        locationService.requestWhenInUsePermission()
                    }

                    PermissionRow(
                        symbol: "location.badge.checkmark",
                        title: "Background Alerts",
                        detail: "Lets iOS detect arrivals when NearNote is closed—without continuous tracking.",
                        isReady: locationService.authorizationStatus == .authorizedAlways,
                        actionTitle: "Enable Background Alerts"
                    ) {
                        locationService.requestAlwaysPermission()
                    }
                }

                if locationService.authorizationStatus == .denied {
                    Section {
                        Button("Open iOS Settings", systemImage: "gear") {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            UIApplication.shared.open(url)
                        }
                    } footer: {
                        Text("Location access was previously declined. You can change it in Settings.")
                    }
                }

                Section {
                    Label("Location is processed on this device and is never used to build a history.", systemImage: "lock.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Location & Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(NearNoteBackground())
        .tint(NearNoteStyle.accent)
    }

    private var hasForegroundLocation: Bool {
        locationService.authorizationStatus == .authorizedWhenInUse ||
        locationService.authorizationStatus == .authorizedAlways
    }
}

private struct PermissionRow: View {
    let symbol: String
    let title: String
    let detail: String
    let isReady: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: isReady ? "checkmark.circle.fill" : symbol)
                .font(.title3)
                .foregroundStyle(isReady ? .green : NearNoteStyle.accent)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !isReady {
                    Button(actionTitle, action: action)
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 5)
                }
            }
        }
        .padding(.vertical, 7)
    }
}
