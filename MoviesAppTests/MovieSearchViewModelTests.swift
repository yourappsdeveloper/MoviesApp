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

private enum StubError: Error {
    case requestFailed
}