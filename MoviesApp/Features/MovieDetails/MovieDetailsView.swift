//
//  MovieDetailsView.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//


import MovieCore
import SwiftUI

struct MovieDetailsView: View {
    @Environment(\.displayScale) private var displayScale
    @State private var retryCount = 0

    let viewModel: MovieDetailsViewModel

    var body: some View {
        content
            .navigationTitle("Movie Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(
                AppTheme.navigationBackground,
                for: .navigationBar
            )
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task(id: retryCount) {
                await viewModel.load()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            loadingView
        case .loaded(let movie):
            detailsView(movie)
        case .failed(let message):
            errorView(message)
        }
    }

    private var loadingView: some View {
        ProgressView("Loading movie details…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func detailsView(_ movie: MovieDetails) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                posterView(movie)

                Text(movie.title)
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)

                ratingView(movie)

                if let runtime = movie.runtime, runtime > 0 {
                    Label("\(runtime) min", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !movie.overview.isEmpty {
                    overviewView(movie.overview)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .scrollIndicators(.hidden)
    }

    private func posterView(_ movie: MovieDetails) -> some View {
        CachedPosterView(
            url: TMDBImageURL.poster(
                path: movie.posterPath,
                width: 160,
                scale: Double(displayScale)
            )
        )
        .frame(width: 160, height: 240)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private func ratingView(_ movie: MovieDetails) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .foregroundStyle(AppTheme.accent)

            Text(
                movie.voteAverage,
                format: .number.precision(.fractionLength(1))
            )
            .fontWeight(.semibold)

            Text("· \(movie.voteCount) votes")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    private func overviewView(_ overview: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Text(overview)
                .font(.body)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                retryCount += 1
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}