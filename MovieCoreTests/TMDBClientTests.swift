//
//  TMDBClientTests.swift
//  MoviesApp
//
//  Created by Alex  on 28.10.2026.
//


import Foundation
import XCTest
@testable import MovieCore

final class TMDBClientTests: XCTestCase {
    func testFetchTrendingMoviesReturnsDecodedMovies() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SuccessURLProtocol.self]

        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let client = TMDBClient(token: "test-token", session: session)

        let movies = try await client.fetchTrendingMovies()

        XCTAssertEqual(movies.count, 1)

        let movie = try XCTUnwrap(movies.first)
        XCTAssertEqual(movie.id, 157336)
        XCTAssertEqual(movie.title, "Interstellar")
        XCTAssertEqual(movie.overview, "A journey through space.")
        XCTAssertEqual(movie.posterPath, "/poster.jpg")
    }
}

private final class SuccessURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(
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
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.badServerResponse)
            )
            return
        }

        client?.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: .notAllowed
        )
        client?.urlProtocol(self, didLoad: responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private var responseData: Data {
        let json = """
        {
            "page": 1,
            "results": [
                {
                    "id": 157336,
                    "title": "Interstellar",
                    "overview": "A journey through space.",
                    "poster_path": "/poster.jpg"
                }
            ],
            "total_pages": 1,
            "total_results": 1
        }
        """

        return Data(json.utf8)
    }
}