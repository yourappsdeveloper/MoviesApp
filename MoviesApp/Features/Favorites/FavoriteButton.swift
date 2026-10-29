//
//  FavoriteButton.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import MovieCore
import SwiftUI

struct FavoriteButton: View {
    enum Style {
        case card
        case toolbar
    }

    @Environment(FavoritesViewModel.self) private var favorites
    let movie: Movie
    var style: Style = .card

    private var isFavorite: Bool {
        favorites.contains(id: movie.id, mediaType: movie.mediaType)
    }

    var body: some View {
        Group {
            switch style {
            case .card:
                button.buttonStyle(.plain)
            case .toolbar:
                button.tint(isFavorite ? Color.red : AppTheme.accent)
            }
        }
        .disabled(favorites.isBusy)
        .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
        .accessibilityIdentifier("favorite-\(movie.mediaType.rawValue)-\(movie.id)")
        .accessibilityValue(isFavorite ? "Saved" : "Not saved")
    }

    private var button: some View {
        Button {
            Task { await favorites.toggle(movie) }
        } label: {
            icon
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch style {
        case .card:
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .foregroundStyle(isFavorite ? Color.red : Color.secondary)
                .padding(10)
                .background(.regularMaterial, in: Circle())
        case .toolbar:
            Image(systemName: isFavorite ? "heart.fill" : "heart")
        }
    }
}
