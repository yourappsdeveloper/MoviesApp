//
//  SeriesDetailsDTOTests.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import Foundation
import XCTest
@testable import MovieCore

final class SeriesDetailsDTOTests: XCTestCase {
    // Preserves series metadata when mapping the API response.
    func testDecodingAndMappingSeriesDetails() throws {
        let data = Data(
            """
            {
                "id": 1396,
                "name": "Breaking Bad",
                "overview": "A chemistry teacher's story.",
                "poster_path": "/series.jpg",
                "backdrop_path": "/backdrop.jpg",
                "first_air_date": "2008-01-20",
                "episode_run_time": [0, 47],
                "vote_average": 8.9,
                "vote_count": 15000,
                "number_of_seasons": 5,
                "number_of_episodes": 62
            }
            """.utf8
        )

        let dto = try JSONDecoder().decode(
            SeriesDetailsDTO.self,
            from: data
        )
        let series = dto.toDomain()

        XCTAssertEqual(series.id, 1396)
        XCTAssertEqual(series.title, "Breaking Bad")
        XCTAssertEqual(series.overview, "A chemistry teacher's story.")
        XCTAssertEqual(series.posterPath, "/series.jpg")
        XCTAssertEqual(series.backdropPath, "/backdrop.jpg")
        XCTAssertEqual(series.releaseDate, "2008-01-20")
        XCTAssertEqual(series.runtime, 47)
        XCTAssertEqual(series.voteAverage, 8.9, accuracy: 0.001)
        XCTAssertEqual(series.voteCount, 15000)
        XCTAssertEqual(series.mediaType, .series)
        XCTAssertEqual(series.numberOfSeasons, 5)
        XCTAssertEqual(series.numberOfEpisodes, 62)
    }

    // Supports responses without optional series metadata.
    func testDecodingSeriesDetailsWithMissingOptionalFields() throws {
        let data = Data(
            """
            {
                "id": 1396,
                "name": "Breaking Bad",
                "overview": "",
                "vote_average": 0,
                "vote_count": 0
            }
            """.utf8
        )

        let dto = try JSONDecoder().decode(
            SeriesDetailsDTO.self,
            from: data
        )
        let series = dto.toDomain()

        XCTAssertEqual(series.title, "Breaking Bad")
        XCTAssertEqual(series.mediaType, .series)
        XCTAssertNil(series.posterPath)
        XCTAssertNil(series.backdropPath)
        XCTAssertNil(series.releaseDate)
        XCTAssertNil(series.runtime)
        XCTAssertNil(series.numberOfSeasons)
        XCTAssertNil(series.numberOfEpisodes)
    }
}
