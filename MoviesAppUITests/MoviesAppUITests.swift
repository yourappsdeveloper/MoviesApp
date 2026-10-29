//
//  MoviesAppUITests.swift
//  MoviesAppUITests
//
//  Created by Alex  on 29.10.2026.
//

import XCTest

// Checks the main navigation using fixed movie data.
final class MoviesAppUITests: XCTestCase {

    // Opens movie details and returns to the trending list.
    @MainActor
    func testOpenMovieDetailsAndReturnToTrending() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        let movieCard = app.descendants(matching: .any)
            .matching(identifier: "movie-card-157336")
            .firstMatch

        XCTAssertTrue(
            movieCard.waitForExistence(timeout: 5),
            "Expected the sample movie in Trending."
        )

        movieCard.tap()

        let detailsNavigationBar = app.navigationBars["Movie Details"]

        XCTAssertTrue(
            detailsNavigationBar.waitForExistence(timeout: 5),
            "Expected the movie details screen."
        )

        XCTAssertTrue(
            app.staticTexts["Interstellar"].waitForExistence(timeout: 5),
            "Expected the selected movie title."
        )

        XCTAssertTrue(
            app.staticTexts[
                "A team of explorers travels through space."
            ].waitForExistence(timeout: 5),
            "Expected the selected movie overview."
        )

        let backButton = detailsNavigationBar.buttons.element(boundBy: 0)

        XCTAssertTrue(backButton.exists)
        backButton.tap()

        XCTAssertTrue(
            app.navigationBars["Trending"].waitForExistence(timeout: 5),
            "Expected to return to Trending."
        )

        XCTAssertTrue(movieCard.waitForExistence(timeout: 5))
    }

    // Finds a movie by title and opens its details from search results.
    @MainActor
    func testSearchMovieAndOpenDetails() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        let searchButton = app.buttons["Search movies"]
        guard searchButton.waitForExistence(timeout: 5) else {
            XCTFail("Expected the search button on Trending.")
            return
        }
        searchButton.tap()

        let searchField = app.textFields["movie-search-field"]
        guard searchField.waitForExistence(timeout: 5) else {
            XCTFail("Expected the movie search field.")
            return
        }
        searchField.tap()
        searchField.typeText("Interstellar\n")

        let searchResults = app.descendants(matching: .any)
            .matching(identifier: "search-results")
            .firstMatch
        guard searchResults.waitForExistence(timeout: 5) else {
            XCTFail("Expected the search results collection.")
            return
        }

        let movieCell = searchResults.descendants(matching: .cell)
            .containing(.any, identifier: "movie-card-157336")
            .firstMatch
        guard movieCell.waitForExistence(timeout: 5) else {
            XCTFail("Expected a matching movie in search results.")
            return
        }

        let cellIsHittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: movieCell
        )
        guard XCTWaiter.wait(for: [cellIsHittable], timeout: 5) == .completed else {
            attachSearchDiagnostics(app: app)
            XCTFail("Expected the movie cell to become tappable.")
            return
        }
        movieCell.tap()

        guard app.navigationBars["Movie Details"].waitForExistence(timeout: 5) else {
            XCTFail("Expected details for the selected search result.")
            return
        }
        XCTAssertTrue(
            app.staticTexts["Interstellar"].waitForExistence(timeout: 5),
            "Expected the selected movie title."
        )
    }

    // Saves the screen and accessibility hierarchy when search cannot be tapped.
    @MainActor
    private func attachSearchDiagnostics(app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Search screen when the cell is not tappable"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Search accessibility hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }

    // Shows an empty state when no movies match the search.
    @MainActor
    func testSearchShowsEmptyStateForUnknownMovie() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        let searchButton = app.buttons["Search movies"]

        guard searchButton.waitForExistence(timeout: 5) else {
            XCTFail("Expected the search button on Trending.")
            return
        }

        searchButton.tap()

        let searchField = app.textFields["movie-search-field"]

        guard searchField.waitForExistence(timeout: 5) else {
            XCTFail("Expected the movie search field.")
            return
        }

        searchField.tap()
        searchField.typeText("NoMatchingMovieXYZ\n")

        let emptyState = app.descendants(matching: .any)
            .matching(identifier: "search-empty-state")
            .firstMatch

        XCTAssertTrue(
            emptyState.waitForExistence(timeout: 5),
            "Expected an empty state for an unknown movie."
        )
    }

    // Finds a series and opens its TV details.
    @MainActor
    func testSearchSeriesAndOpenDetails() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        let searchButton = app.buttons["Search movies"]
        guard searchButton.waitForExistence(timeout: 5) else {
            XCTFail("Expected the search button on Trending.")
            return
        }
        searchButton.tap()

        let seriesButton = app.segmentedControls["search-media-type"]
            .buttons["Series"]
        guard seriesButton.waitForExistence(timeout: 5) else {
            XCTFail("Expected the Series option.")
            return
        }
        seriesButton.tap()

        let searchField = app.textFields["movie-search-field"]
        guard searchField.waitForExistence(timeout: 5) else {
            XCTFail("Expected the search field.")
            return
        }
        searchField.tap()
        searchField.typeText("Breaking Bad\n")

        let seriesCell = app.descendants(matching: .cell)
            .containing(.any, identifier: "movie-card-1396")
            .firstMatch

        let cellIsHittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND isHittable == true"),
            object: seriesCell
        )
        guard XCTWaiter.wait(for: [cellIsHittable], timeout: 5) == .completed else {
            attachSearchDiagnostics(app: app)
            XCTFail("Expected a tappable series result.")
            return
        }
        seriesCell.tap()

        XCTAssertTrue(
            app.navigationBars["Series Details"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.staticTexts["Breaking Bad"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["Seasons: 5"].exists)
        XCTAssertTrue(app.staticTexts["Episodes: 62"].exists)
        XCTAssertFalse(app.navigationBars["Movie Details"].exists)
    }
}
