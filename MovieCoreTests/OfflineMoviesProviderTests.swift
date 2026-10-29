//
//  OfflineMoviesProviderTests.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import Foundation
import XCTest
@testable import MovieCore

final class OfflineMoviesProviderTests: XCTestCase {
    private func root() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    func testTrendingPagesSurviveRelaunchAndMissingPageFails() async throws {
        let directory = root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let upstream = OfflineStub()
        let provider = OfflineMoviesProvider(upstream: upstream, cache: DiskDataStore(directory: directory))
        let online = try await provider.fetchTrendingMovies(page: 1)
        XCTAssertFalse(online.isFromCache)
        _ = try await provider.fetchTrendingMovies(page: 2)
        await upstream.fail(URLError(.notConnectedToInternet))
        let reopened = OfflineMoviesProvider(upstream: upstream, cache: DiskDataStore(directory: directory))
        let first = try await reopened.fetchTrendingMovies(page: 1)
        let second = try await reopened.fetchTrendingMovies(page: 2)
        XCTAssertTrue(first.isFromCache)
        XCTAssertEqual(first.movies.first?.id, 1)
        XCTAssertEqual(second.movies.first?.id, 2)
        do {
            _ = try await reopened.fetchTrendingMovies(page: 3)
            XCTFail("Expected an uncached page to fail.")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        }
    }

    func testDetailsAreSeparatedByMediaType() async throws {
        let directory = root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let upstream = OfflineStub()
        let provider = OfflineMoviesProvider(upstream: upstream, cache: DiskDataStore(directory: directory))
        _ = try await provider.fetchDetails(id: 42, mediaType: .movie)
        _ = try await provider.fetchDetails(id: 42, mediaType: .series)
        await upstream.fail(URLError(.networkConnectionLost))
        let movie = try await provider.fetchDetails(id: 42, mediaType: .movie)
        let series = try await provider.fetchDetails(id: 42, mediaType: .series)
        XCTAssertEqual(movie.mediaType, .movie)
        XCTAssertEqual(series.mediaType, .series)
        XCTAssertTrue(series.isFromCache)
    }

    func testSearchCacheSeparatesQueryPageAndType() async throws {
        let directory = root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let upstream = OfflineStub()
        let provider = OfflineMoviesProvider(upstream: upstream, cache: DiskDataStore(directory: directory))
        _ = try await provider.search(query: "  Same & title  ", page: 1, mediaType: .movie)
        _ = try await provider.search(query: "Same & title", page: 2, mediaType: .series)
        await upstream.fail(URLError(.timedOut))
        let movie = try await provider.search(query: "Same & title", page: 1, mediaType: .movie)
        let series = try await provider.search(query: "Same & title", page: 2, mediaType: .series)
        XCTAssertTrue(movie.isFromCache)
        XCTAssertEqual(series.page, 2)
        XCTAssertEqual(series.movies.first?.mediaType, .series)
        do {
            _ = try await provider.search(query: "Different", page: 1, mediaType: .movie)
            XCTFail("Expected an uncached query to fail.")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut)
        }
    }

    func testHTTPAndDecodingFailuresDoNotReturnStaleContent() async throws {
        let directory = root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let upstream = OfflineStub()
        let provider = OfflineMoviesProvider(upstream: upstream, cache: DiskDataStore(directory: directory))
        _ = try await provider.fetchTrendingMovies(page: 1)
        await upstream.fail(TMDBError.httpStatus(401))
        do {
            _ = try await provider.fetchTrendingMovies(page: 1)
            XCTFail("Expected authorization failure.")
        } catch TMDBError.httpStatus(let code) {
            XCTAssertEqual(code, 401)
        }
        await upstream.fail(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid")))
        do {
            _ = try await provider.fetchTrendingMovies(page: 1)
            XCTFail("Expected a decoding failure.")
        } catch is DecodingError {
            // A valid cache must not hide a broken server response.
        }
    }

    func testCancellationDoesNotUseCache() async throws {
        let directory = root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let upstream = OfflineStub()
        let provider = OfflineMoviesProvider(upstream: upstream, cache: DiskDataStore(directory: directory))
        _ = try await provider.fetchTrendingMovies(page: 1)
        await upstream.fail(CancellationError())
        do {
            _ = try await provider.fetchTrendingMovies(page: 1)
            XCTFail("Expected cancellation.")
        } catch is CancellationError {
            // Cancellation never falls back to saved content.
        }
    }

    func testNetworkRecoveryReturnsFreshResponse() async throws {
        let directory = root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let upstream = OfflineStub()
        let provider = OfflineMoviesProvider(upstream: upstream, cache: DiskDataStore(directory: directory))
        _ = try await provider.fetchTrendingMovies(page: 1)
        await upstream.fail(URLError(.notConnectedToInternet))
        let saved = try await provider.fetchTrendingMovies(page: 1)
        XCTAssertTrue(saved.isFromCache)
        await upstream.fail(nil)
        let fresh = try await provider.fetchTrendingMovies(page: 1)
        XCTAssertFalse(fresh.isFromCache)
    }

    func testCacheOnlyModeWorksWithoutCredentials() async throws {
        let directory = root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let upstream = OfflineStub()
        let cache = DiskDataStore(directory: directory)
        _ = try await OfflineMoviesProvider(upstream: upstream, cache: cache).fetchTrendingMovies(page: 1)
        let before = await upstream.requests
        let offline = OfflineMoviesProvider(upstream: upstream, cache: cache, usesNetwork: false)
        let saved = try await offline.fetchTrendingMovies(page: 1)
        let after = await upstream.requests
        XCTAssertTrue(saved.isFromCache)
        XCTAssertEqual(before, after)
    }

    func testOnlineResponseIsReturnedWhenCacheCannotBeWritten() async throws {
        let directory = root()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data().write(to: directory)
        let provider = OfflineMoviesProvider(upstream: OfflineStub(), cache: DiskDataStore(directory: directory))
        let page = try await provider.fetchTrendingMovies(page: 1)
        XCTAssertEqual(page.movies.first?.id, 1)
        XCTAssertFalse(page.isFromCache)
    }

    func testInvalidArgumentsDoNotReachNetwork() async throws {
        let directory = root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let upstream = OfflineStub()
        let provider = OfflineMoviesProvider(upstream: upstream, cache: DiskDataStore(directory: directory))
        do {
            _ = try await provider.fetchTrendingMovies(page: 0)
            XCTFail("Expected invalid page.")
        } catch TMDBError.invalidPage { }
        do {
            _ = try await provider.search(query: "  ", page: 1, mediaType: .movie)
            XCTFail("Expected empty query.")
        } catch TMDBError.emptySearchQuery { }
        do {
            _ = try await provider.fetchDetails(id: 0, mediaType: .series)
            XCTFail("Expected invalid ID.")
        } catch TMDBError.invalidMovieID { }
        let requests = await upstream.requests
        XCTAssertEqual(requests, 0)
    }

    func testCorruptCachePreservesOriginalNetworkError() async throws {
        let directory = root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = DiskDataStore(directory: directory)
        try await cache.write(Data("invalid".utf8), key: "v1/trending/1")
        let upstream = OfflineStub()
        await upstream.fail(URLError(.notConnectedToInternet))
        do {
            _ = try await OfflineMoviesProvider(upstream: upstream, cache: cache).fetchTrendingMovies(page: 1)
            XCTFail("Expected original connectivity error.")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        }
    }
}

private actor OfflineStub: TrendingMoviesProviding, MovieSearchProviding, MovieDetailsProviding {
    private var failure: (any Error)?
    private(set) var requests = 0

    func fail(_ error: (any Error)?) { failure = error }

    func fetchTrendingMovies(page: Int) async throws -> MoviePage {
        try check()
        return MoviePage(page: page, totalPages: 3, movies: [makeMovie(id: page)])
    }

    func search(query: String, page: Int, mediaType: MediaType) async throws -> MoviePage {
        try check()
        return MoviePage(page: page, totalPages: 3, movies: [makeMovie(id: page, type: mediaType)])
    }

    func fetchDetails(id: Int, mediaType: MediaType) async throws -> MovieDetails {
        try check()
        return MovieDetails(
            id: id, title: "Saved", overview: "Overview", posterPath: nil, backdropPath: nil,
            releaseDate: nil, runtime: nil, voteAverage: 5, voteCount: 1, mediaType: mediaType
        )
    }

    private func check() throws {
        requests += 1
        if let failure { throw failure }
    }

    private func makeMovie(id: Int, type: MediaType = .movie) -> Movie {
        Movie(id: id, title: "Saved", overview: "Overview", posterPath: nil, mediaType: type)
    }
}
