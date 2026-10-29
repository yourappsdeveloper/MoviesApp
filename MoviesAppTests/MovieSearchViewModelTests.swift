//
//  MovieSearchViewModelTests.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//


import MovieCore
import XCTest
@testable import MoviesApp

// Checks search results, errors, and clearing the query.
@MainActor
final class MovieSearchViewModelTests: XCTestCase {

    // Trims the query and publishes movies from the first page.
    func testSearchPublishesMoviesOnSuccess() async {
        let movie = makeMovie()
        let provider = MovieSearchStub(
            result: .success(
                MoviePage(
                    page: 1,
                    totalPages: 2,
                    movies: [movie]
                )
            )
        )
        let viewModel = MovieSearchViewModel(
            moviesProvider: provider
        )

        await viewModel.search(query: "  Interstellar  ")

        guard case .loaded(let movies) = viewModel.state else {
            XCTFail("Expected loaded search results.")
            return
        }

        XCTAssertEqual(movies, [movie])

        let queries = await provider.requestedQueries
        let pages = await provider.requestedPages

        XCTAssertEqual(queries, ["Interstellar"])
        XCTAssertEqual(pages, [1])
    }

    // Publishes an error when the search request fails.
    func testSearchPublishesErrorOnFailure() async {
        let provider = MovieSearchStub(
            result: .failure(.requestFailed)
        )
        let viewModel = MovieSearchViewModel(
            moviesProvider: provider
        )

        await viewModel.search(query: "Interstellar")

        guard case .failed(let message) = viewModel.state else {
            XCTFail("Expected a search error.")
            return
        }

        XCTAssertFalse(message.isEmpty)
    }

    // Clears previous results without requesting an empty query.
    func testEmptyQueryClearsResultsWithoutRequest() async {
        let provider = MovieSearchStub(
            result: .success(
                MoviePage(
                    page: 1,
                    totalPages: 1,
                    movies: [makeMovie()]
                )
            )
        )
        let viewModel = MovieSearchViewModel(
            moviesProvider: provider
        )

        await viewModel.search(query: "Interstellar")

        guard case .loaded = viewModel.state else {
            XCTFail("Expected results before clearing the query.")
            return
        }

        await viewModel.search(query: " \n ")

        guard case .idle = viewModel.state else {
            XCTFail("Expected idle state after clearing the query.")
            return
        }

        let queries = await provider.requestedQueries
        XCTAssertEqual(queries, ["Interstellar"])
    }

    // Creates a movie for search results.
    private func makeMovie() -> Movie {
        Movie(
            id: 157336,
            title: "Interstellar",
            overview: "A journey through space.",
            posterPath: "/poster.jpg"
        )
    }
    
    // Keeps the latest results when an older request finishes afterward.
    func testOlderResponseDoesNotReplaceLatestResults() async {
        let firstRequestStarted = expectation(
            description: "First request started"
        )
        let secondRequestStarted = expectation(
            description: "Second request started"
        )

        let provider = ControlledMovieSearchStub { query in
            switch query {
            case "Interstellar":
                firstRequestStarted.fulfill()
            case "Alien":
                secondRequestStarted.fulfill()
            default:
                break
            }
        }

        let viewModel = MovieSearchViewModel(
            moviesProvider: provider
        )
        let olderMovie = makeMovie()
        let latestMovie = Movie(
            id: 348,
            title: "Alien",
            overview: "A crew encounters an alien.",
            posterPath: nil
        )

        let firstTask = Task {
            await viewModel.search(query: "Interstellar")
        }

        await fulfillment(
            of: [firstRequestStarted],
            timeout: 2
        )

        let secondTask = Task {
            await viewModel.search(query: "Alien")
        }

        await fulfillment(
            of: [secondRequestStarted],
            timeout: 2
        )

        await provider.complete(
            query: "Alien",
            movies: [latestMovie]
        )
        await secondTask.value

        if case .loaded(let latestResults) = viewModel.state {
            XCTAssertEqual(latestResults, [latestMovie])
        } else {
            XCTFail("Expected the latest search results.")
        }

        await provider.complete(
            query: "Interstellar",
            movies: [olderMovie]
        )
        await firstTask.value

        guard case .loaded(let finalResults) = viewModel.state else {
            XCTFail("Expected search results to remain loaded.")
            return
        }

        XCTAssertEqual(finalResults, [latestMovie])
    }
    
    // Searches only the latest query received during the throttle window.
    func testThrottlingSearchesLatestQuery() async {
        let requestStarted = expectation(
            description: "Search request started"
        )
        requestStarted.assertForOverFulfill = true

        let provider = RecordingMovieSearchStub { _ in
            requestStarted.fulfill()
        }
        let viewModel = MovieSearchViewModel(
            moviesProvider: provider
        )
        defer { viewModel.cancelSearch() }

        viewModel.updateQuery("B")
        viewModel.updateQuery("Bat")
        viewModel.updateQuery("Batman")

        await fulfillment(
            of: [requestStarted],
            timeout: 3
        )

        let queries = await provider.requestedQueries
        XCTAssertEqual(queries, ["Batman"])
    }

    // Cancels the pending search when the user clears the field.
    func testClearingQueryCancelsPendingSearch() async {
        let unexpectedRequest = expectation(
            description: "No search request should start"
        )
        unexpectedRequest.isInverted = true

        let provider = RecordingMovieSearchStub { _ in
            unexpectedRequest.fulfill()
        }
        let viewModel = MovieSearchViewModel(
            moviesProvider: provider
        )
        defer { viewModel.cancelSearch() }

        viewModel.updateQuery("Batman")
        viewModel.updateQuery("")

        guard case .idle = viewModel.state else {
            XCTFail("Expected idle state after clearing the query.")
            return
        }

        await fulfillment(
            of: [unexpectedRequest],
            timeout: 1
        )

        let queries = await provider.requestedQueries
        XCTAssertTrue(queries.isEmpty)
    }
}

// Records search parameters and returns a predefined result.
private actor MovieSearchStub: MovieSearchProviding {
    private let result: Result<MoviePage, StubError>

    private(set) var requestedQueries: [String] = []
    private(set) var requestedPages: [Int] = []

    init(result: Result<MoviePage, StubError>) {
        self.result = result
    }

    // Records the query and page before returning the result.
    func searchMovies(
        query: String,
        page: Int
    ) async throws -> MoviePage {
        requestedQueries.append(query)
        requestedPages.append(page)
        return try result.get()
    }
}

// Holds requests until the test explicitly completes them.
private actor ControlledMovieSearchStub: MovieSearchProviding {
    private let onRequest: @Sendable (String) -> Void

    private var pendingRequests: [
        String: CheckedContinuation<MoviePage, any Error>
    ] = [:]

    init(onRequest: @escaping @Sendable (String) -> Void) {
        self.onRequest = onRequest
    }

    // Suspends the request and tells the test it has started.
    func searchMovies(
        query: String,
        page: Int
    ) async throws -> MoviePage {
        try await withCheckedThrowingContinuation { continuation in
            pendingRequests[query] = continuation
            onRequest(query)
        }
    }

    // Resumes a pending request with the supplied movies.
    func complete(query: String, movies: [Movie]) {
        let continuation = pendingRequests.removeValue(
            forKey: query
        )

        continuation?.resume(
            returning: MoviePage(
                page: 1,
                totalPages: 1,
                movies: movies
            )
        )
    }
}

// Records searches and notifies the test when a request starts.
private actor RecordingMovieSearchStub: MovieSearchProviding {
    private let onRequest: @Sendable (String) -> Void

    private(set) var requestedQueries: [String] = []

    init(onRequest: @escaping @Sendable (String) -> Void) {
        self.onRequest = onRequest
    }

    // Records the query and returns an empty results page.
    func searchMovies(
        query: String,
        page: Int
    ) async throws -> MoviePage {
        requestedQueries.append(query)
        onRequest(query)

        return MoviePage(
            page: page,
            totalPages: 1,
            movies: []
        )
    }
}

private enum StubError: Error {
    case requestFailed
}
