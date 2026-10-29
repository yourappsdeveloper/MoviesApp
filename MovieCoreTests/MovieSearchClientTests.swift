//
//  MovieSearchClientTests.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//


import Foundation
import XCTest
@testable import MovieCore

// Checks movie search requests without using the network.
final class MovieSearchClientTests: XCTestCase {

    // Encodes the query and returns the requested page of movies.
    func testSearchMoviesReturnsRequestedPage() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MovieSearchURLProtocol.self]

        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let client = TMDBClient(
            token: "test-token",
            session: session
        )

        let result = try await client.searchMovies(
            query: "  Love & Robots  ",
            page: 2
        )

        XCTAssertEqual(result.page, 2)
        XCTAssertEqual(result.totalPages, 3)
        XCTAssertEqual(result.movies.count, 1)

        let movie = try XCTUnwrap(result.movies.first)
        XCTAssertEqual(movie.id, 42)
        XCTAssertEqual(movie.title, "Love & Robots")
        XCTAssertEqual(movie.overview, "A sample search result.")
        XCTAssertEqual(movie.posterPath, "/poster.jpg")
    }

    // Rejects a query containing only whitespace.
    func testSearchMoviesRejectsEmptyQuery() async {
        let client = TMDBClient(token: "test-token")

        do {
            _ = try await client.searchMovies(
                query: " \n ",
                page: 1
            )
            XCTFail("Expected an empty query error.")
        } catch TMDBError.emptySearchQuery {
            // Expected error.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // Rejects a nonpositive page number.
    func testSearchMoviesRejectsInvalidPage() async {
        let client = TMDBClient(token: "test-token")

        do {
            _ = try await client.searchMovies(
                query: "Interstellar",
                page: 0
            )
            XCTFail("Expected an invalid page error.")
        } catch TMDBError.invalidPage {
            // Expected error.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// Checks the search request and supplies a fixed response.
private final class MovieSearchURLProtocol:
    URLProtocol,
    @unchecked Sendable
{
    // Intercepts requests made by this test session.
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    // Uses the original request without modification.
    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    // Validates query parameters and delivers sample search results.
    override func startLoading() {
        guard let url = request.url,
              let components = URLComponents(
                  url: url,
                  resolvingAgainstBaseURL: false
              ),
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: 200,
                  httpVersion: nil,
                  headerFields: ["Content-Type": "application/json"]
              )
        else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.badURL)
            )
            return
        }

        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "api.themoviedb.org")
        XCTAssertEqual(components.path, "/3/search/movie")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer test-token"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Accept"),
            "application/json"
        )

        let queryItems = components.queryItems ?? []

        XCTAssertEqual(
            queryItems.first { $0.name == "query" }?.value,
            "Love & Robots"
        )
        XCTAssertEqual(
            queryItems.first { $0.name == "page" }?.value,
            "2"
        )
        XCTAssertEqual(
            queryItems.first { $0.name == "include_adult" }?.value,
            "false"
        )

        let data = Data(
            """
            {
                "page": 2,
                "total_pages": 3,
                "total_results": 41,
                "results": [
                    {
                        "id": 42,
                        "title": "Love & Robots",
                        "overview": "A sample search result.",
                        "poster_path": "/poster.jpg"
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

    // No asynchronous work remains to cancel.
    override func stopLoading() {}
}