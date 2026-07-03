import XCTest
import CoreLocation
import SwiftData
@testable import NearNote

@MainActor
final class NearNoteTests: XCTestCase {
    
    var store: ReminderStore!
    
    override func setUp() async throws {
        try await super.setUp()
        // Initialize an in-memory database store for clean tests
        store = ReminderStore(inMemory: true)
    }
    
    override func tearDown() async throws {
        store = nil
        try await super.tearDown()
    }
    
    func testReminderInitialization() {
        let reminder = Reminder(
            title: "Test Grocery",
            notes: "Get milk",
            latitude: 37.7749,
            longitude: -122.4194,
            radius: 250.0,
            triggerOnArrival: true,
            isOneTime: true
        )
        
        XCTAssertEqual(reminder.title, "Test Grocery")
        XCTAssertEqual(reminder.notes, "Get milk")
        XCTAssertEqual(reminder.latitude, 37.7749)
        XCTAssertEqual(reminder.longitude, -122.4194)
        XCTAssertEqual(reminder.radius, 250.0)
        XCTAssertTrue(reminder.triggerOnArrival)
        XCTAssertTrue(reminder.isOneTime)
        XCTAssertTrue(reminder.isEnabled)
        XCTAssertFalse(reminder.isCompleted)
        XCTAssertFalse(reminder.isArchived)
        
        let clRegion = reminder.clRegion
        XCTAssertEqual(clRegion.radius, 250.0)
        XCTAssertEqual(clRegion.center.latitude, 37.7749)
        XCTAssertEqual(clRegion.center.longitude, -122.4194)
        XCTAssertTrue(clRegion.notifyOnEntry)
        XCTAssertFalse(clRegion.notifyOnExit)
    }
    
    func testStoreCRUDOperations() {
        let reminder = Reminder(
            title: "CVS Medicine",
            latitude: 37.7833,
            longitude: -122.4167,
            placeName: "CVS Pharmacy"
        )
        
        store.add(reminder)
        
        let all = store.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.title, "CVS Medicine")
        
        let fetched = store.fetchReminder(withId: reminder.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.placeName, "CVS Pharmacy")
        
        // Update
        reminder.title = "CVS Medicine Updated"
        store.save()
        
        let fetchedUpdated = store.fetchReminder(withId: reminder.id)
        XCTAssertEqual(fetchedUpdated?.title, "CVS Medicine Updated")
        
        // Delete
        store.delete(reminder)
        XCTAssertEqual(store.fetchAll().count, 0)
    }
    
    func testFetchActiveRemindersOnly() {
        let active1 = Reminder(title: "Active 1", latitude: 37.7, longitude: -122.4, placeName: "P1", isEnabled: true, isCompleted: false)
        let active2 = Reminder(title: "Active 2", latitude: 37.8, longitude: -122.5, placeName: "P2", isEnabled: true, isCompleted: false)
        let disabled = Reminder(title: "Disabled", latitude: 37.9, longitude: -122.6, placeName: "P3", isEnabled: false, isCompleted: false)
        let completed = Reminder(title: "Completed", latitude: 38.0, longitude: -122.7, placeName: "P4", isEnabled: true, isCompleted: true)
        let archived = Reminder(title: "Archived", latitude: 38.1, longitude: -122.8, placeName: "P5", isEnabled: true, isArchived: true)
        
        store.add(active1)
        store.add(active2)
        store.add(disabled)
        store.add(completed)
        store.add(archived)
        
        let activeFetched = store.fetchActive()
        XCTAssertEqual(activeFetched.count, 2)
        XCTAssertTrue(activeFetched.contains { $0.title == "Active 1" })
        XCTAssertTrue(activeFetched.contains { $0.title == "Active 2" })
        XCTAssertFalse(activeFetched.contains { $0.title == "Archived" })
    }

    func testReminderLifecycle() {
        let reminder = Reminder(title: "Weekly groceries", latitude: 33.57, longitude: -7.59, isOneTime: false)
        reminder.markDone()
        XCTAssertTrue(reminder.isCompleted)
        XCTAssertFalse(reminder.isEnabled)

        reminder.resume()
        XCTAssertFalse(reminder.isCompleted)
        XCTAssertFalse(reminder.isArchived)
        XCTAssertTrue(reminder.isEnabled)

        reminder.archive()
        XCTAssertTrue(reminder.isArchived)
        XCTAssertFalse(reminder.isEnabled)

        reminder.restoreFromArchive()
        XCTAssertFalse(reminder.isArchived)
        XCTAssertTrue(reminder.isEnabled)
    }

    func testCustomSavedPlaceMetadata() {
        let place = SavedPlace(
            name: "Neighborhood Gym",
            latitude: 33.57,
            longitude: -7.59,
            type: .custom,
            label: "Gym",
            symbolName: "dumbbell.fill",
            sortOrder: 3
        )
        XCTAssertEqual(place.displayLabel, "Gym")
        XCTAssertEqual(place.symbolName, "dumbbell.fill")
        XCTAssertEqual(place.asPlace.name, "Neighborhood Gym")
    }

    func testCategoryDetectionAndSafeSmartDefault() {
        let result = PlaceCategory.detect(from: ["Neighborhood Pharmacy", "pharmacy", "health"])
        XCTAssertEqual(result.category, .pharmacy)
        XCTAssertGreaterThanOrEqual(result.confidence, 0.9)

        let unknown = PlaceCategory.detect(from: ["123 Main Street"])
        XCTAssertNil(unknown.category)
        XCTAssertEqual(unknown.confidence, 0)
    }

    func testParsesFullMapLinksWithoutNetwork() {
        let parser = LinkParserService()
        let google = parser.parse("https://www.google.com/maps/place/Test/@37.7749,-122.4194,16z")
        guard case .place(let googlePlace) = google else { return XCTFail("Expected Google coordinate") }
        XCTAssertEqual(googlePlace.latitude, 37.7749, accuracy: 0.00001)
        XCTAssertEqual(googlePlace.longitude, -122.4194, accuracy: 0.00001)

        let apple = parser.parse("https://maps.apple.com/?q=Coffee&ll=37.78,-122.41")
        guard case .place(let applePlace) = apple else { return XCTFail("Expected Apple coordinate") }
        XCTAssertEqual(applePlace.name, "Coffee")
    }

    func testShortLinksRequireExplicitFallback() {
        XCTAssertEqual(LinkParserService().parse("https://maps.app.goo.gl/example"), .needsExpandedLink)
    }

    func testGoogleRedirectCoordinateFormats() {
        let atCoordinate = LinkResolverService.googleCoordinate(in: "https://www.google.com/maps/place/Test/@33.57311,-7.589843,16z")
        XCTAssertEqual(atCoordinate?.latitude ?? 0, 33.57311, accuracy: 0.00001)
        XCTAssertEqual(atCoordinate?.longitude ?? 0, -7.589843, accuracy: 0.00001)

        let dataCoordinate = LinkResolverService.googleCoordinate(in: "https://www.google.com/maps/data=!3d34.020882!4d-6.841650")
        XCTAssertEqual(dataCoordinate?.latitude ?? 0, 34.020882, accuracy: 0.00001)
        XCTAssertEqual(dataCoordinate?.longitude ?? 0, -6.841650, accuracy: 0.00001)

        let suppliedShortLinkHTML = LinkResolverService.googleCoordinate(
            in: "<meta content=\"https://maps.google.com/maps/api/staticmap?center=33.9836928%2C-6.864896&amp;zoom=13\">"
        )
        XCTAssertEqual(suppliedShortLinkHTML?.latitude ?? 0, 33.9836928, accuracy: 0.00001)
        XCTAssertEqual(suppliedShortLinkHTML?.longitude ?? 0, -6.864896, accuracy: 0.00001)
    }

    func testRadiusChoicesMatchProductLanguage() {
        XCTAssertEqual(RadiusMode.allCases.map(\.title), ["Automatic", "100m", "250m", "500m", "1000m", "Custom"])
        XCTAssertEqual(RadiusMode.meters100.radius(), 100)
        XCTAssertEqual(RadiusMode.meters250.radius(), 250)
        XCTAssertEqual(RadiusMode.meters500.radius(), 500)
        XCTAssertEqual(RadiusMode.meters1000.radius(), 1_000)
        XCTAssertEqual(RadiusMode.custom.radius(customRadius: 650), 650)
    }
}
