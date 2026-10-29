//
//  TrendingViewModelTests.swift
//  MoviesApp
//
//  Created by Alex  on 28.10.2026.
//


// Checks loading, errors, and retry behavior without calling TMDB.
import XCTest
import MovieCore
@testable import MoviesApp

@MainActor
final class TrendingViewModelTests: XCTestCase {
    /// Checks that a successful load puts the returned movies in the loaded state.
    func testLoadPublishesMoviesOnSuccess() async {
        let movie = Movie(
            id: 157336,
            title: "Interstellar",
            overview: "A team travels beyond this galaxy.",
            posterPath: nil
        )
        let provider = TrendingMoviesStub(result: .success([movie]))
        let viewModel = TrendingViewModel(moviesProvider: provider)

        await viewModel.load()

        guard case .loaded(let movies) = viewModel.state else {
            XCTFail("Expected loaded state.")
            return
        }

        XCTAssertEqual(movies.count, 1)
        XCTAssertEqual(movies.first?.id, movie.id)
    }

    /// Checks that a failed request produces the message shown on screen.
    func testLoadPublishesErrorOnFailure() async {
        let provider = TrendingMoviesStub(
            result: .failure(.requestFailed)
        )
        let viewModel = TrendingViewModel(moviesProvider: provider)

        await viewModel.load()

        guard case .failed(let message) = viewModel.state else {
            XCTFail("Expected failed state.")
            return
        }

        XCTAssertEqual(
            message,
            "Unable to load movies. Please try again."
        )
    }

    /// Checks that loading can succeed after an earlier request fails.
    func testLoadRetriesAfterFailure() async {
        let movie = Movie(
            id: 157336,
            title: "Interstellar",
            overview: "",
            posterPath: nil
        )
        let provider = TrendingMoviesStub(
            results: [
                .failure(.requestFailed),
                .success([movie])
            ]
        )
        let viewModel = TrendingViewModel(moviesProvider: provider)

        await viewModel.load()

        guard case .failed = viewModel.state else {
            XCTFail("Expected failed state after the first request.")
            return
        }

        await viewModel.load()

        guard case .loaded(let movies) = viewModel.state else {
            XCTFail("Expected loaded state after retry.")
            return
        }

        XCTAssertEqual(movies.first?.id, movie.id)

        let requestCount = await provider.requestCount
        XCTAssertEqual(requestCount, 2)
    }

    /// Checks that calling load again keeps the result without another request.
    func testLoadDoesNotRequestAgainAfterSuccess() async {
        let provider = TrendingMoviesStub(result: .success([]))
        let viewModel = TrendingViewModel(moviesProvider: provider)

        await viewModel.load()
        await viewModel.load()

        let requestCount = await provider.requestCount
        XCTAssertEqual(requestCount, 1)

        guard case .loaded(let movies) = viewModel.state else {
            XCTFail("Expected loaded state to be preserved.")
            return
        }

        XCTAssertTrue(movies.isEmpty)
    }

    /// Creates a movie with a predictable ID for pagination tests.
    private func makeMovie(id: Int) -> Movie {
        Movie(
            id: id,
            title: "Movie \(id)",
            overview: "",
            posterPath: nil
        )
    }

    /// Appends unique movies in order and stops after the last page.
    func testPaginationAppendsUniqueMoviesAndStopsAtLastPage() async {
        let firstMovie = makeMovie(id: 1)
        let secondMovie = makeMovie(id: 2)

        let provider = TrendingMoviesStub(pages: [
            .success(MoviePage(
                page: 1,
                totalPages: 2,
                movies: [firstMovie]
            )),
            .success(MoviePage(
                page: 2,
                totalPages: 2,
                movies: [firstMovie, secondMovie]
            ))
        ])
        let viewModel = TrendingViewModel(moviesProvider: provider)

        await viewModel.load()
        await viewModel.loadNextPage()
        await viewModel.loadNextPage()

        guard case .loaded(let movies) = viewModel.state else {
            XCTFail("Expected loaded movies.")
            return
        }

        XCTAssertEqual(movies.map(\.id), [1, 2])

        let requestedPages = await provider.requestedPages
        XCTAssertEqual(requestedPages, [1, 2])
    }

    /// Keeps existing movies after failure and retries the same page explicitly.
    func testPaginationPreservesMoviesAndRetriesFailedPage() async {
        let firstMovie = makeMovie(id: 1)
        let secondMovie = makeMovie(id: 2)

        let provider = TrendingMoviesStub(pages: [
            .success(MoviePage(
                page: 1,
                totalPages: 2,
                movies: [firstMovie]
            )),
            .failure(.requestFailed),
            .success(MoviePage(
                page: 2,
                totalPages: 2,
                movies: [secondMovie]
            ))
        ])
        let viewModel = TrendingViewModel(moviesProvider: provider)

        await viewModel.load()
        await viewModel.loadNextPage()

        guard case .loaded(let existingMovies) = viewModel.state else {
            XCTFail("Expected existing movies to remain visible.")
            return
        }

        XCTAssertEqual(existingMovies.map(\.id), [1])

        guard case .failed = viewModel.nextPageState else {
            XCTFail("Expected a pagination error.")
            return
        }

        await viewModel.loadNextPage()

        let pagesBeforeRetry = await provider.requestedPages
        XCTAssertEqual(pagesBeforeRetry, [1, 2])

        await viewModel.retryNextPage()

        guard case .loaded(let updatedMovies) = viewModel.state else {
            XCTFail("Expected loaded movies after retry.")
            return
        }

        XCTAssertEqual(updatedMovies.map(\.id), [1, 2])

        let pagesAfterRetry = await provider.requestedPages
        XCTAssertEqual(pagesAfterRetry, [1, 2, 2])

        guard case .idle = viewModel.nextPageState else {
            XCTFail("Expected pagination to return to idle.")
            return
        }
    }

    // Stops pagination when the API returns an empty page.
    func testLoadNextPageStopsAfterEmptyPage() async {
        let firstMovie = makeMovie(id: 1)
        let provider = TrendingMoviesStub(
            pages: [
                .success(
                    MoviePage(
                        page: 1,
                        totalPages: 3,
                        movies: [firstMovie]
                    )
                ),
                .success(
                    MoviePage(
                        page: 2,
                        totalPages: 3,
                        movies: []
                    )
                )
            ]
        )
        let viewModel = TrendingViewModel(moviesProvider: provider)

        await viewModel.load()
        await viewModel.loadNextPage()
        await viewModel.loadNextPage()

        guard case .loaded(let movies) = viewModel.state else {
            XCTFail("Expected loaded movies.")
            return
        }

        XCTAssertEqual(movies, [firstMovie])

        let requestedPages = await provider.requestedPages
        XCTAssertEqual(requestedPages, [1, 2])

        guard case .idle = viewModel.nextPageState else {
            XCTFail("Expected idle pagination state.")
            return
        }
    }
}

/// Returns prepared pages and records which pages were requested.
private actor TrendingMoviesStub: TrendingMoviesProviding {
    private var results: [Result<MoviePage, StubError>]

    private(set) var requestedPages: [Int] = []

    var requestCount: Int {
        requestedPages.count
    }

    /// Wraps one movie list in a first-page response.
    init(result: Result<[Movie], StubError>) {
        self.results = [
            result.map {
                MoviePage(page: 1, totalPages: 1, movies: $0)
            }
        ]
    }

    /// Prepares first-page responses for loading and retry tests.
    init(results: [Result<[Movie], StubError>]) {
        self.results = results.map { result in
            result.map {
                MoviePage(page: 1, totalPages: 1, movies: $0)
            }
        }
    }

    /// Prepares page responses for pagination tests.
    init(pages: [Result<MoviePage, StubError>]) {
        self.results = pages
    }

    /// Records the requested page and returns the next prepared result.
    func fetchTrendingMovies(page: Int) async throws -> MoviePage {
        requestedPages.append(page)

        guard !results.isEmpty else {
            throw StubError.unexpectedRequest
        }

        return try results.removeFirst().get()
    }
}

private enum StubError: Error {
    case requestFailed
    case unexpectedRequest
}
