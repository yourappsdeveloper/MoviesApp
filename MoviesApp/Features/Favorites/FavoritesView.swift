//
//  FavoritesView.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import MovieCore
import SwiftUI

struct FavoritesView: View {
    @Environment(FavoritesViewModel.self) private var favorites
    @Environment(\.dismiss) private var dismiss
    let movieDetailsProvider: any MovieDetailsProviding
    @State private var navigationPath: [Movie] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                if favorites.movies.isEmpty {
                    ContentUnavailableView("No favorites yet", systemImage: "heart")
                        .accessibilityIdentifier("favorites-empty-state")
                } else {
                    MoviesCollectionView(
                        movies: favorites.movies,
                        onNearEnd: {},
                        onSelectMovie: { navigationPath.append($0) }
                    )
                    .accessibilityIdentifier("favorites-results")
                }
            }
            .navigationTitle("Favorites")
            .navigationDestination(for: Movie.self) { movie in
                MovieDetailsView(
                    movieID: movie.id, mediaType: movie.mediaType,
                    moviesProvider: movieDetailsProvider
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(AppTheme.accent)
    }
}
