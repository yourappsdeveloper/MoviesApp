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
    private var latestQuery = ""
    private var throttleTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    
    init(moviesProvider: any MovieSearchProviding) {
        self.moviesProvider = moviesProvider
    }
    
    // Keeps the latest query and schedules one search per throttle window.
    func updateQuery(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard trimmedQuery != latestQuery else {
            return
        }

        latestQuery = trimmedQuery

        currentRequestID = UUID()
        searchTask?.cancel()
        searchTask = nil

        guard !trimmedQuery.isEmpty else {
            throttleTask?.cancel()
            throttleTask = nil
            state = .idle
            return
        }

        state = .loading

        guard throttleTask == nil else {
            return
        }

        throttleTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return
            }

            guard let self else {
                return
            }

            self.throttleTask = nil
            self.startSearch()
        }
    }
    
    // Starts a request using the latest query.
    private func startSearch() {
        let query = latestQuery

        searchTask = Task { [weak self] in
            guard let self, !Task.isCancelled else {
                return
            }

            await self.search(query: query)
        }
    }
    
    // Cancels pending work and resets the search state.
    func cancelSearch() {
        currentRequestID = UUID()

        throttleTask?.cancel()
        throttleTask = nil

        searchTask?.cancel()
        searchTask = nil

        latestQuery = ""
        state = .idle
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
