//
//  TMDBImageURLTests.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//


import XCTest
@testable import MovieCore

/// Checks poster size selection without downloading images.
final class TMDBImageURLTests: XCTestCase {
    /// Converts points to pixels and picks the smallest sufficient size.
    func testPosterUsesDisplayScale() {
        let url = TMDBImageURL.poster(
            path: "/poster.jpg",
            width: 140,
            scale: 3
        )

        XCTAssertEqual(
            url?.absoluteString,
            "https://image.tmdb.org/t/p/w500/poster.jpg"
        )
    }

    /// Keeps an exact size match instead of requesting a larger image.
    func testPosterUsesExactSizeMatch() {
        let url = TMDBImageURL.poster(
            path: "/poster.jpg",
            width: 260,
            scale: 3
        )

        XCTAssertEqual(
            url?.absoluteString,
            "https://image.tmdb.org/t/p/w780/poster.jpg"
        )
    }

    /// Uses the original when all resized variants are too small.
    func testPosterUsesOriginalForLargeViews() {
        let url = TMDBImageURL.poster(
            path: "/poster.jpg",
            width: 400,
            scale: 3
        )

        XCTAssertEqual(
            url?.absoluteString,
            "https://image.tmdb.org/t/p/original/poster.jpg"
        )
    }

    /// Leaves missing posters to the UI placeholder.
    func testPosterReturnsNilForMissingPath() {
        let url = TMDBImageURL.poster(
            path: nil,
            width: 140,
            scale: 3
        )

        XCTAssertNil(url)
    }
}