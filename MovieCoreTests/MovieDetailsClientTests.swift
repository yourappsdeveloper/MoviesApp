//
//  MovieDetailsClientTests.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import Foundation
import XCTest
@testable import MovieCore

// Checks movie details requests without using the network.
final class MovieDetailsClientTests: XCTestCase {

    // Sends the expected request and returns decoded movie details.
    func testFetchMovieDetailsReturnsMovie() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MovieDetailsURLProtocol.self]

        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let client = TMDBClient(
            token: "test-token",
            session: session
        )

        let movie = try await client.fetchMovieDetails(id: 157336)

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

    // Rejects a nonpositive movie ID.
    func testFetchMovieDetailsRejectsInvalidID() async {
        let client = TMDBClient(token: "test-token")

        do {
            _ = try await client.fetchMovieDetails(id: 0)
            XCTFail("Expected an invalid movie ID error.")
        } catch TMDBError.invalidMovieID {
            // Expected error.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// Returns a fixed response for movie details requests.
private final class MovieDetailsURLProtocol:
    URLProtocol,
    @unchecked Sendable {
    // Handles requests made by this test session.
    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    // Uses the request without changing it.
    override static func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    // Checks the request and delivers a sample response.
    override func startLoading() {
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.themoviedb.org/3/movie/157336"
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

        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: 200,
                  httpVersion: nil,
                  headerFields: ["Content-Type": "application/json"]
              )
        else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.badServerResponse)
            )
            return
        }

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

        client?.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: .notAllowed
        )
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    // The response is delivered immediately, so no work needs cancelling.
    override func stopLoading() {}
}
