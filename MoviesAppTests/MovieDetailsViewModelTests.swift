//
//  MovieDetailsViewModelTests.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//


import MovieCore
import XCTest
@testable import MoviesApp

// Checks how movie details loading updates the screen state.
@MainActor
final class MovieDetailsViewModelTests: XCTestCase {

    // Publishes movie details after a successful request.
    func testLoadPublishesMovieOnSuccess() async {
        let movie = makeMovie()
        let provider = MovieDetailsStub(result: .success(movie))
        let viewModel = MovieDetailsViewModel(
            movieID: movie.id,
            moviesProvider: provider
        )

        await viewModel.load()

        guard case .loaded(let loadedMovie) = viewModel.state else {
            XCTFail("Expected loaded movie details.")
            return
        }

        XCTAssertEqual(loadedMovie.id, movie.id)
        XCTAssertEqual(loadedMovie.title, movie.title)

        let requestedIDs = await provider.requestedIDs
        XCTAssertEqual(requestedIDs, [movie.id])
    }

    // Publishes an error when the request fails.
    func testLoadPublishesErrorOnFailure() async {
        let provider = MovieDetailsStub(
            result: .failure(.requestFailed)
        )
        let viewModel = MovieDetailsViewModel(
            movieID: 157336,
            moviesProvider: provider
        )

        await viewModel.load()

        guard case .failed(let message) = viewModel.state else {
            XCTFail("Expected an error state.")
            return
        }

        XCTAssertFalse(message.isEmpty)

        let requestedIDs = await provider.requestedIDs
        XCTAssertEqual(requestedIDs, [157336])
    }

    // Creates sample details shared by these tests.
    private func makeMovie() -> MovieDetails {
        MovieDetails(
            id: 157336,
            title: "Interstellar",
            overview: "A journey through space.",
            posterPath: "/poster.jpg",
            backdropPath: "/backdrop.jpg",
            releaseDate: "2014-11-05",
            runtime: 169,
            voteAverage: 8.4,
            voteCount: 35000
        )
    }
}

// Records requested IDs and returns a predefined result.
private actor MovieDetailsStub: MovieDetailsProviding {
    private let result: Result<MovieDetails, StubError>
    private(set) var requestedIDs: [Int] = []

    init(result: Result<MovieDetails, StubError>) {
        self.result = result
    }

    // Returns sample details or throws the configured error.
    func fetchMovieDetails(id: Int) async throws -> MovieDetails {
        requestedIDs.append(id)
        return try result.get()
    }
}

private enum StubError: Error {
    case requestFailed
}