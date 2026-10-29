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
}
