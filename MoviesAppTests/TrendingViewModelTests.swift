//
//  TrendingViewModelTests.swift
//  MoviesApp
//
//  Created by Alex  on 28.10.2026.
//


import XCTest
import MovieCore
@testable import MoviesApp

@MainActor
final class TrendingViewModelTests: XCTestCase {
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
}

private actor TrendingMoviesStub: TrendingMoviesProviding {
    private var results: [Result<[Movie], StubError>]

    private(set) var requestCount = 0

    init(result: Result<[Movie], StubError>) {
        self.results = [result]
    }

    init(results: [Result<[Movie], StubError>]) {
        self.results = results
    }

    func fetchTrendingMovies() async throws -> [Movie] {
        requestCount += 1

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
