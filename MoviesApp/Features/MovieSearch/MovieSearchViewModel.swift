//
//  MovieSearchViewModel.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//


import Foundation
import MovieCore
import Observation

@MainActor
@Observable
final class MovieSearchViewModel {
    
    enum State {
        case idle
        case loading
        case loaded([Movie])
        case failed(String)
    }

    private(set) var state: State = .idle

    private let moviesProvider: any MovieSearchProviding
    private var currentRequestID = UUID()

    init(moviesProvider: any MovieSearchProviding) {
        self.moviesProvider = moviesProvider
    }

    // Searches movies and publishes only the latest request's result.
    func search(query: String) async {
        let requestID = UUID()
        currentRequestID = requestID

        let trimmedQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedQuery.isEmpty else {
            state = .idle
            return
        }

        guard !Task.isCancelled else {
            state = .idle
            return
        }

        state = .loading

        do {
            let result = try await moviesProvider.searchMovies(
                query: trimmedQuery,
                page: 1
            )

            try Task.checkCancellation()

            guard currentRequestID == requestID else {
                return
            }

            state = .loaded(result.movies)
        } catch {
            guard currentRequestID == requestID else {
                return
            }

            if Task.isCancelled || error is CancellationError {
                state = .idle
                return
            }

            state = .failed(
                "Unable to search movies. Please try again."
            )
        }
    }
}
