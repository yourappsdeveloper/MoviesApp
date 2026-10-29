//
//  FavoritesViewModel.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import MovieCore
import Observation

@MainActor
@Observable
final class FavoritesViewModel {
    private(set) var movies: [Movie] = []
    private(set) var isBusy = false
    var errorMessage: String?
    private let repository: any FavoritesStoring

    init(repository: any FavoritesStoring) {
        self.repository = repository
    }

    func contains(id: Int, mediaType: MediaType) -> Bool {
        movies.contains { $0.id == id && $0.mediaType == mediaType }
    }

    func load() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            movies = try await repository.load()
            errorMessage = nil
        } catch {
            errorMessage = "Unable to read favorites. Please try again."
        }
    }

    func toggle(_ movie: Movie) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            movies = try await repository.toggle(movie)
            errorMessage = nil
        } catch {
            errorMessage = "Unable to save favorites. Please try again."
        }
    }
}
