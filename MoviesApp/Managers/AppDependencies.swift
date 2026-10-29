//
//  AppDependencies.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import Foundation
import MovieCore

@MainActor
struct AppDependencies {
    let trending: TrendingViewModel
    let search: MovieSearchViewModel
    let details: any MovieDetailsProviding
    let favorites: FavoritesViewModel

    init() {
        let token = ProcessInfo.processInfo.environment["TMDB_READ_ACCESS_TOKEN"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let upstream: any TrendingMoviesProviding & MovieSearchProviding & MovieDetailsProviding
        var usesNetwork = !token.isEmpty
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            upstream = UITestMoviesProvider()
            usesNetwork = true
        } else {
            upstream = TMDBClient(token: token)
        }
#else
        upstream = TMDBClient(token: token)
#endif
        let provider = OfflineMoviesProvider(
            upstream: upstream,
            cache: DiskDataStore(
                directory: AppStorage.directory.appendingPathComponent("Responses"),
                byteLimit: 20 * 1024 * 1024
            ),
            usesNetwork: usesNetwork
        )
        trending = TrendingViewModel(moviesProvider: provider)
        search = MovieSearchViewModel(moviesProvider: provider)
        details = provider
        favorites = FavoritesViewModel(repository: FavoritesRepository(
            fileURL: AppStorage.directory.appendingPathComponent("favorites-v1.json")
        ))
    }
}
