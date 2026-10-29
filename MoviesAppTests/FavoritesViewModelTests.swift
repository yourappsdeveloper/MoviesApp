//
//  FavoritesViewModelTests.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import Foundation
import MovieCore
import XCTest
@testable import MoviesApp

@MainActor
final class FavoritesViewModelTests: XCTestCase {
    private let movie = Movie(id: 42, title: "Movie", overview: "Overview", posterPath: nil)
    private let series = Movie(id: 42, title: "Series", overview: "Overview", posterPath: nil, mediaType: .series)

    func testToggleAndLoadKeepMovieAndSeriesIndependent() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("favorites.json")
        let viewModel = FavoritesViewModel(repository: FavoritesRepository(fileURL: file))
        await viewModel.toggle(movie)
        await viewModel.toggle(series)
        XCTAssertTrue(viewModel.contains(id: 42, mediaType: .movie))
        XCTAssertTrue(viewModel.contains(id: 42, mediaType: .series))
        await viewModel.toggle(movie)
        XCTAssertFalse(viewModel.contains(id: 42, mediaType: .movie))
        let reopened = FavoritesViewModel(repository: FavoritesRepository(fileURL: file))
        await reopened.load()
        XCTAssertEqual(reopened.movies, [series])
        XCTAssertFalse(reopened.isBusy)
        XCTAssertNil(reopened.errorMessage)
    }

    func testFailedSaveKeepsPublishedFavoritesAndCanRetry() async {
        let repository = FavoritesViewModelStub(movies: [movie])
        let viewModel = FavoritesViewModel(repository: repository)
        await viewModel.load()
        await repository.setFailure(true)
        await viewModel.toggle(movie)
        XCTAssertEqual(viewModel.movies, [movie])
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isBusy)
        await repository.setFailure(false)
        await viewModel.toggle(movie)
        XCTAssertTrue(viewModel.movies.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testFailedReloadKeepsExistingFavorites() async {
        let repository = FavoritesViewModelStub(movies: [movie])
        let viewModel = FavoritesViewModel(repository: repository)
        await viewModel.load()
        await repository.setFailure(true)
        await viewModel.load()
        XCTAssertEqual(viewModel.movies, [movie])
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isBusy)
    }
}

private actor FavoritesViewModelStub: FavoritesStoring {
    private var movies: [Movie]
    private var shouldFail = false

    init(movies: [Movie]) { self.movies = movies }
    func setFailure(_ value: Bool) { shouldFail = value }

    func load() throws -> [Movie] {
        if shouldFail { throw URLError(.cannotWriteToFile) }
        return movies
    }

    func toggle(_ movie: Movie) throws -> [Movie] {
        if shouldFail { throw URLError(.cannotWriteToFile) }
        movies.removeAll { $0.id == movie.id && $0.mediaType == movie.mediaType }
        return movies
    }
}
