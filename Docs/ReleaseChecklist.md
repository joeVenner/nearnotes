# NearNote 1.0 release checklist

## Required external values

Before archiving, edit `project.yml` and set:

```yaml
NEARNOTE_PRIVACY_URL: "https://YOUR-DOMAIN/privacy"
NEARNOTE_SUPPORT_URL: "https://YOUR-DOMAIN/support"
```

Keep these empty for the simplest privacy-first V1 unless their complete production infrastructure and App Privacy disclosures are ready:

```yaml
GOOGLE_PLACES_API_KEY: ""
NEARNOTE_TELEMETRY_ENDPOINT: ""
NEARNOTE_FEEDBACK_ENDPOINT: ""
```

Google Maps link pasting still works without a Google Places API key.

## Local release validation

1. Install a current iOS Simulator runtime in Xcode Settings > Components.
2. Run `xcodegen generate`.
3. Open `NearNote.xcodeproj`.
4. Select the NearNote target, choose your Apple Developer team, and enable automatic signing.
5. Confirm bundle ID `com.mosaab.NearNote` is available in your account.
6. Run unit tests.
7. Run Product > Analyze.
8. Test on a physical iPhone with Location set to Always and Notifications enabled.
9. Test foreground, background, and terminated arrival delivery.
10. Test Google short links, offline behavior, archive/resume, saved places, quiet hours, and report sharing.

## Archive

1. Set Version to `1.0` and Build to `1`.
2. Select Any iOS Device (arm64).
3. Choose Product > Archive.
4. In Organizer, choose Validate App and resolve every error.
5. Generate and inspect the Privacy Report from the archive.
6. Choose Distribute App > App Store Connect > Upload.

For every subsequent upload, increment Build to `2`, `3`, and so on.

## App Store Connect

1. Create an iOS app named NearNote using bundle ID `com.mosaab.NearNote`.
2. Suggested SKU: `nearnote-ios-001`.
3. Primary category: Productivity. Secondary: Utilities.
4. Add the privacy policy and support URLs.
5. Complete Age Rating, Content Rights, DSA status, availability, and pricing.
6. Complete App Privacy based on the exact production configuration.
7. Upload 1–10 truthful iPhone screenshots, preferably the largest accepted portrait size.
8. Add description, subtitle, keywords, copyright, and review contact details.
9. Select the processed build.
10. Test through TestFlight before submission.
11. Add the version for review, then submit the draft submission.

## Suggested App Review note

NearNote creates on-device reminders triggered using Apple region monitoring. It does not use continuous background GPS. No account is required. To test, create a reminder, choose a nearby location, allow notifications and Always Location, and enter the selected region. Map links from Apple Maps, Google Maps, and Waze can be pasted during place selection. Anonymous usage reporting is disabled in this build unless explicitly configured and enabled by the user.

