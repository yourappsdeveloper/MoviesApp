//
//  ContentView.swift
//  MoviesApp
//
//  Created by Alex  on 28.10.2026.
//

import Foundation
import SwiftUI
import MovieCore

struct ContentView: View {
    var body: some View {
        Text("Check the console for trending movies.")
            .padding()
            .task {
                await checkTrendingMovies()
            }
    }

    private func checkTrendingMovies() async {
        guard let rawToken = ProcessInfo.processInfo.environment[
            "TMDB_READ_ACCESS_TOKEN"
        ] else {
            print("Missing TMDB_READ_ACCESS_TOKEN.")
            return
        }

        let token = rawToken.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !token.isEmpty else {
            print("TMDB_READ_ACCESS_TOKEN is empty.")
            return
        }

        let client = TMDBClient(token: token)

        do {
            let movies = try await client.fetchTrendingMovies()

            try Task.checkCancellation()

            print("Loaded movies: \(movies.count)")

            if let firstMovie = movies.first {
                print("First movie: \(firstMovie.title)")
            }
        } catch {
            guard !Task.isCancelled else {
                return
            }

            print("Trending request failed: \(error)")
        }
    }
}

#Preview {
    ContentView()
}
