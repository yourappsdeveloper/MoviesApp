//
//  FavoritesOfflineUITests.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import XCTest

@MainActor
final class FavoritesOfflineUITests: XCTestCase {
    func testFavoritePersistsAndCanBeRemovedAfterOfflineRelaunch() {
        let storage = UUID().uuidString
        let app = launch(storage: storage)
        let heart = app.buttons["favorite-movie-157336"].firstMatch
        tapWhenReady(heart)
        waitForValue("Saved", element: heart)
        app.terminate()

        launch(app, storage: storage, offline: true)
        waitFor(app.descendants(matching: .any)["saved-content-notice"].firstMatch)
        waitForValue("Saved", element: app.buttons["favorite-movie-157336"].firstMatch)
        let favorites = openFavorites(app)
        let savedHeart = favorites.buttons["favorite-movie-157336"].firstMatch
        tapWhenReady(savedHeart)
        waitFor(app.descendants(matching: .any)["favorites-empty-state"].firstMatch)
        app.terminate()

        launch(app, storage: storage, offline: true)
        tapWhenReady(app.buttons["Favorites"])
        waitFor(app.descendants(matching: .any)["favorites-empty-state"].firstMatch)
    }

    func testPreviouslyOpenedMovieDetailsAreAvailableFromFavoritesOffline() {
        let storage = UUID().uuidString
        let app = launch(storage: storage)
        let heart = app.buttons["favorite-movie-157336"].firstMatch
        tapWhenReady(heart)
        waitForValue("Saved", element: heart)
        openCard(id: 157336, in: app)
        waitFor(app.navigationBars["Movie Details"])
        waitFor(app.staticTexts["A team of explorers travels through space."])
        app.terminate()

        launch(app, storage: storage, offline: true)
        let favorites = openFavorites(app)
        openCard(id: 157336, in: favorites)
        waitFor(app.navigationBars["Movie Details"])
        waitFor(app.descendants(matching: .any)["saved-content-notice"].firstMatch)
        waitFor(app.staticTexts["A team of explorers travels through space."])
    }

    func testSeriesSearchDetailsAndFavoriteAreRestoredOffline() {
        let storage = UUID().uuidString
        let app = launch(storage: storage)
        let results = searchSeries(app)
        let heart = results.buttons["favorite-tv-1396"].firstMatch
        tapWhenReady(heart)
        waitForValue("Saved", element: heart)
        openCard(id: 1396, in: results)
        waitFor(app.staticTexts["Seasons: 5"])
        app.terminate()

        launch(app, storage: storage, offline: true)
        let savedResults = searchSeries(app)
        waitFor(app.descendants(matching: .any)["saved-content-notice"].firstMatch)
        waitForValue("Saved", element: savedResults.buttons["favorite-tv-1396"].firstMatch)
        openCard(id: 1396, in: savedResults)
        waitFor(app.navigationBars["Series Details"])
        waitFor(app.staticTexts["Seasons: 5"])
        waitFor(app.staticTexts["Episodes: 62"])
    }

    func testColdOfflineLaunchShowsRetryAndEmptyFavorites() {
        let app = XCUIApplication()
        launch(app, storage: UUID().uuidString, offline: true)
        waitFor(app.buttons["Try Again"])
        tapWhenReady(app.buttons["Favorites"])
        waitFor(app.descendants(matching: .any)["favorites-empty-state"].firstMatch)
    }

    @discardableResult
    private func launch(
        _ app: XCUIApplication = XCUIApplication(), storage: String, offline: Bool = false
    ) -> XCUIApplication {
        continueAfterFailure = false
        app.launchArguments = ["-ui-testing", "-ui-test-storage", storage]
        if offline { app.launchArguments.append("-ui-testing-offline") }
        app.launch()
        return app
    }

    // A presented sheet can coexist with Trending in the accessibility tree.
    private func openFavorites(_ app: XCUIApplication) -> XCUIElement {
        tapWhenReady(app.buttons["Favorites"])
        let results = app.descendants(matching: .any)["favorites-results"].firstMatch
        waitFor(results)
        return results
    }

    private func searchSeries(_ app: XCUIApplication) -> XCUIElement {
        tapWhenReady(app.buttons["Search movies"])
        let picker = app.segmentedControls["search-media-type"].buttons["Series"]
        tapWhenReady(picker)
        let field = app.textFields["movie-search-field"]
        tapWhenReady(field)
        field.typeText("Breaking Bad\n")
        let results = app.descendants(matching: .any)["search-results"].firstMatch
        waitFor(results)
        return results
    }

    // Resolve the card inside its collection, not an underlying screen.
    private func openCard(id: Int, in container: XCUIElement) {
        let cell = container.descendants(matching: .cell)
            .containing(.any, identifier: "movie-card-\(id)").firstMatch
        tapWhenReady(cell)
    }

    private func tapWhenReady(
        _ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line
    ) {
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND isHittable == true AND isEnabled == true"),
            object: element
        )
        guard XCTWaiter.wait(for: [ready], timeout: 5) == .completed else {
            attachDiagnostics()
            XCTFail("Expected a visible, enabled element: \(element)", file: file, line: line)
            return
        }
        element.tap()
    }

    private func waitFor(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
    }

    private func waitForValue(_ value: String, element: XCUIElement) {
        let saved = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND value == %@", value), object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 5), .completed)
    }

    private func attachDiagnostics() {
        let app = XCUIApplication()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Favorites offline UI failure"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Favorites offline accessibility hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }
}
