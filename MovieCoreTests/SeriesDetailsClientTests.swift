//
//  SeriesDetailsClientTests.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import Foundation
import XCTest
@testable import MovieCore

final class SeriesDetailsClientTests: XCTestCase {
    // Requests TV details and returns a correctly mapped series.
    func testFetchSeriesDetailsReturnsSeries() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SeriesDetailsURLProtocol.self]

        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let client = TMDBClient(
            token: "test-token",
            session: session
        )

        let series = try await client.fetchDetails(
            id: 1396,
            mediaType: .series
        )

        XCTAssertEqual(series.id, 1396)
        XCTAssertEqual(series.title, "Breaking Bad")
        XCTAssertEqual(series.mediaType, .series)
        XCTAssertEqual(series.releaseDate, "2008-01-20")
        XCTAssertEqual(series.runtime, 47)
        XCTAssertEqual(series.numberOfSeasons, 5)
        XCTAssertEqual(series.numberOfEpisodes, 62)
    }
}

private final class SeriesDetailsURLProtocol:
    URLProtocol,
    @unchecked Sendable {
    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {
        validateRequest()

        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: 200,
                  httpVersion: nil,
                  headerFields: ["Content-Type": "application/json"]
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let data = Data(
            """
            {
                "id": 1396,
                "name": "Breaking Bad",
                "overview": "A chemistry teacher's story.",
                "poster_path": "/series.jpg",
                "backdrop_path": "/backdrop.jpg",
                "first_air_date": "2008-01-20",
                "episode_run_time": [47],
                "vote_average": 8.9,
                "vote_count": 15000,
                "number_of_seasons": 5,
                "number_of_episodes": 62
            }
            """.utf8
        )

        client?.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: .notAllowed
        )
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    private func validateRequest() {
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.themoviedb.org/3/tv/1396"
        )
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer test-token"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Accept"),
            "application/json"
        )
    }

    override func stopLoading() {}
}
