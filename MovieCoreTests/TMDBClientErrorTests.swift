//
//  TMDBClientErrorTests.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//


import Foundation
import XCTest
@testable import MovieCore

// Checks how the client handles unsuccessful API responses.
final class TMDBClientErrorTests: XCTestCase {

    // Returns the HTTP status when the server rejects authentication.
    func testSearchThrowsHTTPStatusForUnauthorizedResponse() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UnauthorizedURLProtocol.self]

        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let client = TMDBClient(
            token: "test-token",
            session: session
        )

        do {
            _ = try await client.searchMovies(
                query: "Interstellar",
                page: 1
            )

            XCTFail("Expected HTTP 401.")
        } catch TMDBError.httpStatus(let statusCode) {
            XCTAssertEqual(statusCode, 401)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// Returns HTTP 401 without contacting the real API.
private final class UnauthorizedURLProtocol:
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

    // Delivers an unauthorized response with an empty body.
    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: 401,
                  httpVersion: nil,
                  headerFields: nil
              )
        else {
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
        client?.urlProtocolDidFinishLoading(self)
    }

    // The response is delivered immediately.
    override func stopLoading() {}
}