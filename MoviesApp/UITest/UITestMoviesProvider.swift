//
//  UITestMoviesProvider.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

#if DEBUG
import Foundation
import MovieCore

// Supplies predictable movie and series data for UI tests.
struct UITestMoviesProvider:
    TrendingMoviesProviding,
    MovieDetailsProviding,
    MovieSearchProviding {

    private let detailsRecovery = DetailsRecoveryScenario()

    private let movie = Movie(
        id: 157336,
        title: "Interstellar",
        overview: "A team of explorers travels through space.",
        posterPath: nil
    )

    private let series = Movie(
        id: 1396,
        title: "Breaking Bad",
        overview: "A chemistry teacher starts a dangerous new life.",
        posterPath: nil,
        mediaType: .series
    )

    func fetchTrendingMovies(page: Int) async throws -> MoviePage {
        try Task.checkCancellation()
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-offline") {
            throw URLError(.notConnectedToInternet)
        }

        return MoviePage(
            page: page,
            totalPages: 1,
            movies: page == 1 ? [movie] : []
        )
    }

    func search(
        query: String,
        page: Int,
        mediaType: MediaType
    ) async throws -> MoviePage {
        try Task.checkCancellation()
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-offline") {
            throw URLError(.notConnectedToInternet)
        }

        let item = mediaType == .movie ? movie : series
        let matches = item.title.localizedCaseInsensitiveContains(query)

        return MoviePage(
            page: page,
            totalPages: 1,
            movies: page == 1 && matches ? [item] : []
        )
    }

    func fetchDetails(
        id: Int,
        mediaType: MediaType
    ) async throws -> MovieDetails {
        try Task.checkCancellation()
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-offline") {
            throw URLError(.notConnectedToInternet)
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-details-recovery") {
            if await detailsRecovery.shouldFail() {
                throw URLError(.notConnectedToInternet)
            }
        }

        let item = mediaType == .movie ? movie : series

        guard id == item.id else {
            throw TMDBError.invalidMovieID
        }

        return MovieDetails(
            id: item.id,
            title: item.title,
            overview: item.overview,
            posterPath: nil,
            backdropPath: nil,
            releaseDate: mediaType == .movie
                ? "2014-11-05"
                : "2008-01-20",
            runtime: mediaType == .movie ? 169 : 47,
            voteAverage: 8.4,
            voteCount: 35000,
            mediaType: mediaType,
            numberOfSeasons: mediaType == .series ? 5 : nil,
            numberOfEpisodes: mediaType == .series ? 62 : nil
        )
    }
}

// Simulates one offline details request followed by restored connectivity.
private actor DetailsRecoveryScenario {
    private var failuresRemaining = 1

    func shouldFail() -> Bool {
        guard failuresRemaining > 0 else { return false }
        failuresRemaining -= 1
        return true
    }
}
#endif
