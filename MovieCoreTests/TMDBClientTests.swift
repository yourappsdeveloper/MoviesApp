//
//  TMDBClientTests.swift
//  MoviesApp
//
//  Created by Alex  on 28.10.2026.
//

// Checks API response decoding and domain mapping without a network connection.
import Foundation
import XCTest
@testable import MovieCore

final class TMDBClientTests: XCTestCase {
    /// Checks that the client turns a successful JSON response into domain movies.
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

    /// Checks that the client preserves pagination metadata.
    func testFetchTrendingMoviesReturnsPageInformation() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SuccessURLProtocol.self]

        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let client = TMDBClient(token: "test-token", session: session)

        let result = try await client.fetchTrendingMovies(page: 1)

        XCTAssertEqual(result.page, 1)
        XCTAssertEqual(result.totalPages, 1)
        XCTAssertEqual(result.movies.count, 1)
        XCTAssertEqual(result.movies.first?.id, 157336)
    }

    /// Rejects an invalid page before making a network request.
    func testFetchTrendingMoviesRejectsPageZero() async {
        let client = TMDBClient(token: "test-token")

        do {
            _ = try await client.fetchTrendingMovies(page: 0)
            XCTFail("Expected an invalid page error.")
        } catch TMDBError.invalidPage {
            // Expected error.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

/// Supplies a fixed response only to sessions that register this helper.
private final class SuccessURLProtocol: URLProtocol, @unchecked Sendable {
    /// Handles every request made through this test session.
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    /// Leaves the intercepted request unchanged.
    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    /// Delivers a prepared HTTP 200 response and JSON to the session.
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

    /// Nothing to cancel: the response is delivered synchronously.
    override func stopLoading() {}

    /// A small movie page used instead of a live TMDB response.
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
