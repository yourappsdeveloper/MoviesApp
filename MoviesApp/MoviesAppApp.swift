//
//  MoviesAppApp.swift
//  MoviesApp
//
//  Created by Alex  on 28.10.2026.
//

import Foundation
import SwiftUI
import MovieCore

@main
struct MoviesAppApp: App {
    
    @State private var trendingViewModel: TrendingViewModel?
    @State private var searchViewModel: MovieSearchViewModel?
    private let movieDetailsProvider: (any MovieDetailsProviding)?
    
    init() {
#if DEBUG
if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
    let provider = UITestMoviesProvider()

    _trendingViewModel = State(
        initialValue: TrendingViewModel(
            moviesProvider: provider
        )
    )

    _searchViewModel = State(
        initialValue: MovieSearchViewModel(
            moviesProvider: provider
        )
    )

    movieDetailsProvider = provider

    return
}
#endif
        
        let token = ProcessInfo.processInfo.environment["TMDB_READ_ACCESS_TOKEN"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let token, !token.isEmpty {
            let client = TMDBClient(token: token)
            _trendingViewModel = State(initialValue: TrendingViewModel(moviesProvider: client))
            _searchViewModel = State(initialValue: MovieSearchViewModel(moviesProvider: client))
            movieDetailsProvider = client
        } else {
            _trendingViewModel = State(initialValue: nil)
            _searchViewModel = State(initialValue: nil)
            movieDetailsProvider = nil
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if let trendingViewModel,
               let searchViewModel,
               let movieDetailsProvider {
                TrendingView(
                    viewModel: trendingViewModel,
                    movieDetailsProvider: movieDetailsProvider,
                    searchViewModel: searchViewModel
                )
            } else {
                ContentUnavailableView("Configuration unavailable",
                                       systemImage: "gearshape",
                                       description: Text("Please check the local launch configuration."))
            }
        }
    }
}
