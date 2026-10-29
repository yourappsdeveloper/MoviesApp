//
//  SeriesSearchClientTests.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import Foundation
import XCTest
@testable import MovieCore

final class SeriesSearchClientTests: XCTestCase {
    // Checks the TV endpoint, query encoding, and decoded results.
    func testSearchSeriesReturnsRequestedPage() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SeriesSearchURLProtocol.self]

        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let client = TMDBClient(
            token: "test-token",
            session: session
        )

        let result = try await client.search(
            query: "  Love & Robots  ",
            page: 2,
            mediaType: .series
        )

        XCTAssertEqual(result.page, 2)
        XCTAssertEqual(result.totalPages, 3)
        XCTAssertEqual(result.movies.count, 1)

        let series = try XCTUnwrap(result.movies.first)
        XCTAssertEqual(series.id, 42)
        XCTAssertEqual(series.title, "Love & Robots")
        XCTAssertEqual(series.overview, "A sample series.")
        XCTAssertEqual(series.posterPath, "/series.jpg")
        XCTAssertEqual(series.mediaType, .series)
    }
}

private final class SeriesSearchURLProtocol:
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

        validateRequest(url: url)

        let data = Data(
            """
            {
                "page": 2,
                "total_pages": 3,
                "total_results": 41,
                "results": [
                    {
                        "id": 42,
                        "name": "Love & Robots",
                        "overview": "A sample series.",
                        "poster_path": "/series.jpg"
                    }
                ]
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

    private func validateRequest(url: URL) {
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "api.themoviedb.org")
        XCTAssertEqual(url.path, "/3/search/tv")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer test-token"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Accept"),
            "application/json"
        )

        let items = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )?.queryItems ?? []

        XCTAssertEqual(
            items.first { $0.name == "query" }?.value,
            "Love & Robots"
        )
        XCTAssertEqual(items.first { $0.name == "page" }?.value, "2")
        XCTAssertEqual(
            items.first { $0.name == "include_adult" }?.value,
            "false"
        )
    }

    override func stopLoading() {}
}
