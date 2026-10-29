//
//  MovieCardView.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//


import SwiftUI
import MovieCore

/// Shows a movie poster, title, and short overview.
struct MovieCardView: View {
    
    @Environment(\.displayScale) private var displayScale
    let movie: Movie

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            poster
            details
        }
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.black.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 3, y: 2)
        .accessibilityElement(children: .combine)
    }

    private var poster: some View {
        Rectangle()
            .fill(Color(uiColor: .systemGray5))
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    posterImage(size: geometry.size)
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }

    private func posterImage(size: CGSize) -> some View {
        CachedPosterView(
            url: TMDBImageURL.poster(
                path: movie.posterPath,
                width: Double(size.width),
                scale: Double(displayScale)
            )
        )
        .frame(width: size.width, height: size.height)
        .clipped()
    }
    
    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            title
            overview
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var title: some View {
        Text(movie.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(2, reservesSpace: true)
    }

    private var overview: some View {
        Text(movie.overview)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3, reservesSpace: true)
    }
}

#Preview {
    MovieCardView(
        movie: Movie(
            id: 157336,
            title: "Interstellar",
            overview: "A team of explorers travels beyond this galaxy.",
            posterPath: "/1E5baAaEse26fej7uHcjOgEE2t2.jpg"
        )
    )
    .frame(width: 180)
    .padding()
}
