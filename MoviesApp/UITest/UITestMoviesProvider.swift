//
//  UITestMoviesProvider.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

#if DEBUG
import MovieCore
import Foundation

// Supplies predictable movie data for UI tests.
struct UITestMoviesProvider:
    TrendingMoviesProviding,
    MovieDetailsProviding,
    MovieSearchProviding {
    private let movie = Movie(
        id: 157336,
        title: "Interstellar",
        overview: "A team of explorers travels through space.",
        posterPath: nil
    )

    // Returns one trending movie with no additional pages.
    func fetchTrendingMovies(page: Int) async throws -> MoviePage {
        try Task.checkCancellation()

        return MoviePage(
            page: page,
            totalPages: 1,
            movies: page == 1 ? [movie] : []
        )
    }

    // Returns details for the movie used by the navigation tests.
    func fetchMovieDetails(id: Int) async throws -> MovieDetails {
        try Task.checkCancellation()

        return MovieDetails(
            id: movie.id,
            title: movie.title,
            overview: movie.overview,
            posterPath: nil,
            backdropPath: nil,
            releaseDate: "2014-11-05",
            runtime: 169,
            voteAverage: 8.4,
            voteCount: 35000
        )
    }

    // Matches the sample movie against the entered title.
    func searchMovies(
        query: String,
        page: Int
    ) async throws -> MoviePage {
        try Task.checkCancellation()

        let matches = movie.title.localizedCaseInsensitiveContains(
            query
        )

        return MoviePage(
            page: page,
            totalPages: 1,
            movies: page == 1 && matches ? [movie] : []
        )
    }
}
#endif
