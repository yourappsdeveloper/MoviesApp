//
//  OfflineViewModelTests.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import MovieCore
import XCTest
@testable import MoviesApp

@MainActor
final class OfflineViewModelTests: XCTestCase {
    func testTrendingRetainsSavedNoticeWhenFreshPageIsAppended() async {
        let provider = SavedContentStub()
        let viewModel = TrendingViewModel(moviesProvider: provider)
        await viewModel.load()
        XCTAssertTrue(viewModel.isShowingSavedData)
        await viewModel.loadNextPage()
        XCTAssertTrue(viewModel.isShowingSavedData)
        guard case .loaded(let movies) = viewModel.state else {
            XCTFail("Expected loaded content.")
            return
        }
        XCTAssertEqual(movies.map(\.id), [1, 2])
    }

    func testSearchClearsSavedNoticeWhenFreshResultsArriveOrSearchIsCancelled() async {
        let provider = SavedContentStub()
        let viewModel = MovieSearchViewModel(moviesProvider: provider)
        await viewModel.search(query: "saved")
        XCTAssertTrue(viewModel.isShowingSavedData)
        await viewModel.search(query: "fresh")
        XCTAssertFalse(viewModel.isShowingSavedData)
        await viewModel.search(query: "saved")
        viewModel.cancelSearch()
        XCTAssertFalse(viewModel.isShowingSavedData)
    }

    func testSavedSeriesDetailsRetainMediaTypeAndDate() async {
        let viewModel = MovieDetailsViewModel(
            movieID: 42, mediaType: .series, moviesProvider: SavedContentStub()
        )
        await viewModel.load()
        XCTAssertTrue(viewModel.isShowingSavedData)
        XCTAssertNotNil(viewModel.releaseDate)
        guard case .loaded(let details) = viewModel.state else {
            XCTFail("Expected saved details.")
            return
        }
        XCTAssertEqual(details.mediaType, .series)
        XCTAssertEqual(details.numberOfSeasons, 5)
    }
}

private struct SavedContentStub: TrendingMoviesProviding, MovieSearchProviding, MovieDetailsProviding {
    func fetchTrendingMovies(page: Int) async throws -> MoviePage {
        var result = MoviePage(page: page, totalPages: 2, movies: [movie(id: page)])
        result.isFromCache = page == 1
        return result
    }

    func search(query: String, page: Int, mediaType: MediaType) async throws -> MoviePage {
        var result = MoviePage(page: page, totalPages: 1, movies: [movie(id: 42)])
        result.isFromCache = query == "saved"
        return result
    }

    func fetchDetails(id: Int, mediaType: MediaType) async throws -> MovieDetails {
        var result = MovieDetails(
            id: id, title: "Series", overview: "Saved", posterPath: nil, backdropPath: nil,
            releaseDate: "2008-01-20", runtime: 47, voteAverage: 8, voteCount: 10,
            mediaType: mediaType, numberOfSeasons: 5, numberOfEpisodes: 62
        )
        result.isFromCache = true
        return result
    }

    private func movie(id: Int) -> Movie {
        Movie(id: id, title: "Saved", overview: "Overview", posterPath: nil)
    }
}
