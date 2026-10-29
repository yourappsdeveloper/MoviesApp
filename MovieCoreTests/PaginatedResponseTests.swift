//
//  PaginatedResponseTests.swift
//  MoviesApp
//
//  Created by Alex  on 28.10.2026.
//

// Checks page metadata and the movies inside a paginated response.
import Foundation
import XCTest
@testable import MovieCore

final class PaginatedResponseTests: XCTestCase {
    /// Checks that page numbers, totals, and nested movies decode correctly.
    func testDecodingMoviePage() throws {
        // Arrange
        let json = """
        {
            "page": 2,
            "results": [
                {
                    "id": 157336,
                    "title": "Interstellar",
                    "overview": "A team travels beyond this galaxy.",
                    "poster_path": null
                }
            ],
            "total_pages": 5,
            "total_results": 81
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()

        // Act
        let response = try decoder.decode(
            PaginatedResponse<MovieDTO>.self,
            from: data
        )

        // Assert
        XCTAssertEqual(response.page, 2)
        XCTAssertEqual(response.totalPages, 5)
        XCTAssertEqual(response.totalResults, 81)
        XCTAssertEqual(response.results.count, 1)

        let movie = try XCTUnwrap(response.results.first)
        XCTAssertEqual(movie.id, 157336)
    }
}
