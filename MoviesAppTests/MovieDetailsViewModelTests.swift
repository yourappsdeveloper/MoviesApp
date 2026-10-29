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

    // Creates sample details with a configurable release date.
    private func makeMovie(
        releaseDate: String? = "2014-11-05"
    ) -> MovieDetails {
        MovieDetails(
            id: 157336,
            title: "Interstellar",
            overview: "A journey through space.",
            posterPath: "/poster.jpg",
            backdropPath: "/backdrop.jpg",
            releaseDate: releaseDate,
            runtime: 169,
            voteAverage: 8.4,
            voteCount: 35000
        )
    }

    // Parses the release date using the Gregorian calendar in GMT.
    func testReleaseDateParsesValidValue() async {
        let provider = MovieDetailsStub(
            result: .success(makeMovie(releaseDate: "2014-11-05"))
        )
        let viewModel = MovieDetailsViewModel(
            movieID: 157336,
            moviesProvider: provider
        )

        await viewModel.load()

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt

        let expectedDate = calendar.date(
            from: DateComponents(
                year: 2014,
                month: 11,
                day: 5
            )
        )

        XCTAssertNotNil(expectedDate)
        XCTAssertEqual(viewModel.releaseDate, expectedDate)
    }

    // Returns no date when the API provides no usable value.
    func testReleaseDateIsNilForMissingOrInvalidValues() async {
        let values: [String?] = [
            nil,
            "",
            "not-a-date",
            "2014-02-30"
        ]

        for value in values {
            let provider = MovieDetailsStub(
                result: .success(makeMovie(releaseDate: value))
            )
            let viewModel = MovieDetailsViewModel(
                movieID: 157336,
                moviesProvider: provider
            )

            await viewModel.load()

            XCTAssertNil(
                viewModel.releaseDate,
                "Expected no date for: \(value ?? "nil")"
            )
        }
    }

    // Passes the series ID and media type to the details provider.
    func testLoadSeriesDetailsUsesSelectedMediaType() async {
        let series = MovieDetails(
            id: 1396,
            title: "Breaking Bad",
            overview: "A chemistry teacher's story.",
            posterPath: nil,
            backdropPath: nil,
            releaseDate: "2008-01-20",
            runtime: 47,
            voteAverage: 8.9,
            voteCount: 15000,
            mediaType: .series,
            numberOfSeasons: 5,
            numberOfEpisodes: 62
        )
        let provider = MovieDetailsStub(
            result: .success(series)
        )
        let viewModel = MovieDetailsViewModel(
            movieID: 1396,
            mediaType: .series,
            moviesProvider: provider
        )

        await viewModel.load()

        let requestedIDs = await provider.requestedIDs
        let mediaTypes = await provider.requestedMediaTypes

        XCTAssertEqual(requestedIDs, [1396])
        XCTAssertEqual(mediaTypes, [.series])

        guard case .loaded(let details) = viewModel.state else {
            XCTFail("Expected loaded series details.")
            return
        }

        XCTAssertEqual(details.title, "Breaking Bad")
        XCTAssertEqual(details.mediaType, .series)
    }
}

// Records requested IDs and returns a predefined result.
private actor MovieDetailsStub: MovieDetailsProviding {
    private let result: Result<MovieDetails, StubError>
    private(set) var requestedIDs: [Int] = []
    private(set) var requestedMediaTypes: [MediaType] = []

    init(result: Result<MovieDetails, StubError>) {
        self.result = result
    }

    // Returns sample details or throws the configured error.
    func fetchDetails(
        id: Int,
        mediaType: MediaType
    ) async throws -> MovieDetails {
        requestedIDs.append(id)
        requestedMediaTypes.append(mediaType)
        return try result.get()
    }
}

private enum StubError: Error {
    case requestFailed
}
