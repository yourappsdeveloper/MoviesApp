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
    
    init() {
        let token = ProcessInfo.processInfo.environment["TMDB_READ_ACCESS_TOKEN"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let token, !token.isEmpty {
            let client = TMDBClient(token: token)
            _trendingViewModel = State(initialValue: TrendingViewModel(moviesProvider: client))
        } else {
            _trendingViewModel = State(initialValue: nil)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if let trendingViewModel {
                TrendingView(viewModel: trendingViewModel)
            } else {
                ContentUnavailableView("Configuration unavailable",
                                       systemImage: "gearshape",
                                       description: Text("Please check the local launch configuration."))
            }
        }
    }
}
