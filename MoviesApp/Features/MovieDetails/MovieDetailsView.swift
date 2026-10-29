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

    private func detailsView(_ movie: MovieDetails) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                headerView(movie)

                VStack(alignment: .leading, spacing: 20) {
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

                    if !movie.overview.isEmpty {
                        overviewView(movie.overview)
                    }
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .center)
            }
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
    
    private func headerView(_ movie: MovieDetails) -> some View {
        posterView(movie)
            .padding(.vertical, 24)
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
