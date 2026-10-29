//
//  MovieDetailsDTOTests.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//


import Foundation
import XCTest
@testable import MovieCore

// Checks decoding and mapping of movie details.
final class MovieDetailsDTOTests: XCTestCase {

    // Preserves movie details when converting the API response.
    func testDecodingAndMappingMovieDetails() throws {
        let data = Data(
            """
            {
                "id": 157336,
                "title": "Interstellar",
                "overview": "A journey through space.",
                "poster_path": "/poster.jpg",
                "backdrop_path": "/backdrop.jpg",
                "release_date": "2014-11-05",
                "runtime": 169,
                "vote_average": 8.4,
                "vote_count": 35000
            }
            """.utf8
        )

        let dto = try JSONDecoder().decode(
            MovieDetailsDTO.self,
            from: data
        )
        let movie = dto.toDomain()

        XCTAssertEqual(movie.id, 157336)
        XCTAssertEqual(movie.title, "Interstellar")
        XCTAssertEqual(movie.overview, "A journey through space.")
        XCTAssertEqual(movie.posterPath, "/poster.jpg")
        XCTAssertEqual(movie.backdropPath, "/backdrop.jpg")
        XCTAssertEqual(movie.releaseDate, "2014-11-05")
        XCTAssertEqual(movie.runtime, 169)
        XCTAssertEqual(movie.voteAverage, 8.4, accuracy: 0.001)
        XCTAssertEqual(movie.voteCount, 35000)
    }

    // Accepts missing images and release information.
    func testDecodingMovieDetailsWithNullFields() throws {
        let data = Data(
            """
            {
                "id": 1,
                "title": "Upcoming Movie",
                "overview": "",
                "poster_path": null,
                "backdrop_path": null,
                "release_date": null,
                "runtime": null,
                "vote_average": 0,
                "vote_count": 0
            }
            """.utf8
        )

        let dto = try JSONDecoder().decode(
            MovieDetailsDTO.self,
            from: data
        )
        let movie = dto.toDomain()

        XCTAssertNil(movie.posterPath)
        XCTAssertNil(movie.backdropPath)
        XCTAssertNil(movie.releaseDate)
        XCTAssertNil(movie.runtime)
    }
}