//
//  MovieDetailsViewModel.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//


import MovieCore
import Observation

@MainActor
@Observable
final class MovieDetailsViewModel {
    enum State {
        case idle
        case loading
        case loaded(MovieDetails)
        case failed(String)
    }

    private(set) var state: State = .idle

    private let movieID: Int
    private let moviesProvider: any MovieDetailsProviding

    init(
        movieID: Int,
        moviesProvider: any MovieDetailsProviding
    ) {
        self.movieID = movieID
        self.moviesProvider = moviesProvider
    }

    // Loads details once, while allowing retries after a failure.
    func load() async {
        switch state {
        case .loading, .loaded:
            return
        case .idle, .failed:
            break
        }

        guard !Task.isCancelled else {
            return
        }

        state = .loading

        do {
            let movie = try await moviesProvider.fetchMovieDetails(
                id: movieID
            )

            try Task.checkCancellation()

            state = .loaded(movie)
        } catch {
            if Task.isCancelled || error is CancellationError {
                state = .idle
                return
            }

            state = .failed(
                "Unable to load movie details. Please try again."
            )
        }
    }
}