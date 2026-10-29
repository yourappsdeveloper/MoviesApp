//
//  MovieSearchView.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//


import MovieCore
import SwiftUI

struct MovieSearchView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var navigationPath: [Int] = []
    @State private var isSearchActive = true

    let viewModel: MovieSearchViewModel
    let movieDetailsProvider: any MovieDetailsProviding

    var body: some View {
        NavigationStack(path: $navigationPath) {
            content
                .navigationTitle("Search")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(
                    text: $query,
                    isPresented: $isSearchActive,
                    prompt: "Search movies"
                )
                .onSubmit(of: .search) {
                    isSearchActive = false
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                .toolbarBackground(
                    AppTheme.navigationBackground,
                    for: .navigationBar
                )
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .navigationDestination(for: Int.self) { movieID in
                    MovieDetailsView(
                        movieID: movieID,
                        moviesProvider: movieDetailsProvider
                    )
                }
        }
        .tint(AppTheme.accent)
        .onChange(of: query) { _, newValue in
            // Keep results when the system closes the search interface.
            guard !newValue.isEmpty || isSearchActive else {
                return
            }

            viewModel.updateQuery(newValue)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            promptView
        case .loading:
            loadingView
        case .loaded(let movies):
            if movies.isEmpty {
                emptyView
            } else {
                resultsView(movies)
            }
        case .failed(let message):
            errorView(message)
        }
    }

    private var promptView: some View {
        ContentUnavailableView(
            "Search Movies",
            systemImage: "magnifyingglass",
            description: Text("Enter a movie title to start searching.")
        )
    }

    private var loadingView: some View {
        ProgressView("Searching…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        ContentUnavailableView.search(text: query)
            .accessibilityIdentifier("search-empty-state")
    }

    // Displays search results using the existing movie collection.
    private func resultsView(_ movies: [Movie]) -> some View {
        MoviesCollectionView(
            movies: movies,
            onNearEnd: {},
            onSelectMovie: { movie in
                navigationPath.append(movie.id)
            }
        )
        .accessibilityIdentifier("search-results")
    }

    // Shows a failed search with an explicit retry action.
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                viewModel.retrySearch()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
