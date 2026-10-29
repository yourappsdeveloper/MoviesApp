//
//  SeriesDTOTests.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import Foundation
import XCTest
@testable import MovieCore

final class SeriesDTOTests: XCTestCase {
    // Decodes a TV result and maps it to a series card.
    func testDecodingAndMappingSeries() throws {
        let data = Data(
            """
            {
                "id": 1396,
                "name": "Breaking Bad",
                "overview": "A chemistry teacher starts a dangerous new life.",
                "poster_path": "/series.jpg"
            }
            """.utf8
        )

        let dto = try JSONDecoder().decode(
            SeriesDTO.self,
            from: data
        )
        let series = dto.toDomain()

        XCTAssertEqual(series.id, 1396)
        XCTAssertEqual(series.title, "Breaking Bad")
        XCTAssertEqual(
            series.overview,
            "A chemistry teacher starts a dangerous new life."
        )
        XCTAssertEqual(series.posterPath, "/series.jpg")
        XCTAssertEqual(series.mediaType, .series)
    }

    // Supports series without a poster.
    func testDecodingSeriesWithNullPoster() throws {
        let data = Data(
            """
            {
                "id": 1396,
                "name": "Breaking Bad",
                "overview": "",
                "poster_path": null
            }
            """.utf8
        )

        let dto = try JSONDecoder().decode(
            SeriesDTO.self,
            from: data
        )
        let series = dto.toDomain()

        XCTAssertEqual(series.title, "Breaking Bad")
        XCTAssertEqual(series.mediaType, .series)
        XCTAssertNil(series.posterPath)
    }
}
