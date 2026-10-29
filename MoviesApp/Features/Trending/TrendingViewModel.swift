//
//  TrendingViewModel.swift
//  MoviesApp
//
//  Created by Alex  on 28.10.2026.
//


import Foundation
import Observation
import MovieCore

@MainActor
@Observable
final class TrendingViewModel {
  
    enum State {
        case idle
        case loading
        case loaded([Movie])
        case failed(String)
    }

    private(set) var state: State = .idle
    private let moviesProvider: any TrendingMoviesProviding

    init(moviesProvider: any TrendingMoviesProviding) {
        self.moviesProvider = moviesProvider
    }

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
            let result = try await moviesProvider.fetchTrendingMovies(page: 1)

            try Task.checkCancellation()

            state = .loaded(result.movies)
        } catch {
            if Task.isCancelled || error is CancellationError {
                state = .idle
                return
            }

            state = .failed(
                "Unable to load movies. Please try again."
            )
        }
    }
}
