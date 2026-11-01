import XCTest

final class MovieDetailsRetryUITests: XCTestCase {
    // Exercises the actual retry button without depending on the host's Wi-Fi.
    @MainActor
    func testDetailsRetryRecoversAfterConnectivityFailure() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-details-recovery"]
        app.launch()

        let movieCard = app.descendants(matching: .any)
            .matching(identifier: "movie-card-157336").firstMatch
        waitUntilHittable(movieCard)
        movieCard.tap()

        XCTAssertTrue(app.navigationBars["Movie Details"].waitForExistence(timeout: 5))
        let error = app.staticTexts["Unable to load movie details. Please try again."]
        let retry = app.buttons["Try Again"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        waitUntilHittable(retry)
        retry.tap()

        let overview = app.staticTexts["A team of explorers travels through space."]
        XCTAssertTrue(overview.waitForExistence(timeout: 10))
        XCTAssertFalse(error.exists)
        XCTAssertFalse(retry.exists)
    }

    @MainActor
    private func waitUntilHittable(_ element: XCUIElement) {
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND isHittable == true AND isEnabled == true"),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
    }
}
