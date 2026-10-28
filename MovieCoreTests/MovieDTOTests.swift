//
//  MovieDTOTests.swift
//  MoviesApp
//
//  Created by Alex  on 28.10.2026.
//


// Checks how movie JSON fields and missing posters are decoded.
import Foundation
import XCTest
@testable import MovieCore

final class MovieDTOTests: XCTestCase {
    /// Checks that JSON fields, including poster_path, decode correctly.
    func testDecodingMovieWithPoster() throws {
        // Arrange
        let json = """
        {
            "id": 157336,
            "title": "Interstellar",
            "overview": "A team travels beyond this galaxy.",
            "poster_path": "/poster.jpg"
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()

        // Act
        let movie = try decoder.decode(MovieDTO.self, from: data)

        // Assert
        XCTAssertEqual(movie.id, 157336)
        XCTAssertEqual(movie.title, "Interstellar")
        XCTAssertEqual(
            movie.overview,
            "A team travels beyond this galaxy."
        )
        XCTAssertEqual(movie.posterPath, "/poster.jpg")
    }

    /// Checks that a null poster decodes as nil.
    func testDecodingMovieWithNullPoster() throws {
        // Arrange
        let json = """
        {
            "id": 157336,
            "title": "Interstellar",
            "overview": "",
            "poster_path": null
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()

        // Act
        let movie = try decoder.decode(MovieDTO.self, from: data)

        // Assert
        XCTAssertNil(movie.posterPath)
    }
}
