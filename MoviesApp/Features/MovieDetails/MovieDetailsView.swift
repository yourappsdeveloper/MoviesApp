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
    @State private var viewModel: MovieDetailsViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    init(
        movieID: Int,
        moviesProvider: any MovieDetailsProviding
    ) {
        _viewModel = State(
            initialValue: MovieDetailsViewModel(
                movieID: movieID,
                moviesProvider: moviesProvider
            )
        )
    }

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

    // Adapts the details layout to the available width and text size.
    private func detailsView(_ movie: MovieDetails) -> some View {
        GeometryReader { geometry in
            let usesWideLayout = geometry.size.width >= 600
                && !dynamicTypeSize.isAccessibilitySize

            ScrollView {
                VStack(spacing: 0) {
                    headerView(movie, usesWideLayout: usesWideLayout)

                    VStack(alignment: .leading, spacing: 20) {
                        if !usesWideLayout {
                            movieInfoView(movie)
                        }

                        if !movie.overview.isEmpty {
                            overviewView(movie.overview)
                        }
                    }
                    .frame(maxWidth: 680, alignment: .leading)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    // Groups the title, rating, release date, and runtime.
    private func movieInfoView(_ movie: MovieDetails) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(movie.title)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)

            ratingView(movie)

            releaseDateView

            if let runtime = movie.runtime, runtime > 0 {
                Label("\(runtime) min", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Loads a poster at the resolution needed for its displayed size.
    private func posterView(
        _ movie: MovieDetails,
        width: CGFloat = 160
    ) -> some View {
        CachedPosterView(
            url: TMDBImageURL.poster(
                path: movie.posterPath,
                width: Double(width),
                scale: Double(displayScale)
            )
        )
        .frame(width: width, height: width * 1.5)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8))
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

    private var releaseDateView: some View {
        Group {
            if let date = viewModel.releaseDate {
                Label {
                    Text(
                        date,
                        format: Date.FormatStyle(
                            date: .abbreviated,
                            time: .omitted,
                            timeZone: .gmt
                        )
                    )
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
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

    // Places movie information beside the poster on wider screens.
    private func headerView(
        _ movie: MovieDetails,
        usesWideLayout: Bool
    ) -> some View {
        Group {
            if usesWideLayout {
                HStack(alignment: .center, spacing: 24) {
                    posterView(movie, width: 120)

                    movieInfoView(movie)
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(16)
                .frame(maxWidth: .infinity)
                .environment(\.colorScheme, .dark)
            } else {
                posterView(movie)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
        }
        .background {
            backdropView(movie)
        }
    }

    private func backdropView(_ movie: MovieDetails) -> some View {
        AppTheme.navigationBackground
            .overlay {
                if movie.backdropPath != nil {
                    GeometryReader { geometry in
                        CachedPosterView(
                            url: TMDBImageURL.backdrop(
                                path: movie.backdropPath,
                                width: Double(geometry.size.width),
                                scale: Double(displayScale)
                            )
                        )
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                        .clipped()
                        .overlay {
                            AppTheme.navigationBackground.opacity(0.75)
                        }
                    }
                }
            }
            .clipped()
            .accessibilityHidden(true)
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
