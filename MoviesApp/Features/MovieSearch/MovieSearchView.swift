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
    @State private var navigationPath: [Movie] = []
    @FocusState private var isSearchFocused: Bool

    let viewModel: MovieSearchViewModel
    let movieDetailsProvider: any MovieDetailsProviding

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top, spacing: 0) {
                mediaTypePicker
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                searchBar
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                SavedContentNotice(isVisible: viewModel.isShowingSavedData)
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
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
            .navigationDestination(for: Movie.self) { movie in
                MovieDetailsView(
                    movieID: movie.id,
                    mediaType: movie.mediaType,
                    moviesProvider: movieDetailsProvider
                )
            }
        }
        .tint(AppTheme.accent)
        .onChange(of: query) { _, newValue in
            viewModel.updateQuery(newValue)
        }
    }

    // Keeps the query when dismissing the keyboard.
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField(
                    viewModel.mediaType == .movie
                        ? "Search movies"
                        : "Search series",
                    text: $query
                )
                .focused($isSearchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    isSearchFocused = false
                }
                .accessibilityIdentifier("movie-search-field")
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .background(.regularMaterial, in: Capsule())

            Button {
                isSearchFocused = false
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .frame(width: 50, height: 50)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hide keyboard")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
            viewModel.mediaType == .movie
                ? "Search Movies"
                : "Search Series",
            systemImage: "magnifyingglass",
            description: Text("Choose Movies or Series, then enter a title.")
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
                navigationPath.append(movie)
            }
        )
        .accessibilityIdentifier("search-results")
    }

    // Selects the content type before searching.
    private var mediaTypePicker: some View {
        Picker(
            "Content type",
            selection: Binding(
                get: { viewModel.mediaType },
                set: { viewModel.selectMediaType($0) }
            )
        ) {
            ForEach(MediaType.allCases, id: \.self) { mediaType in
                Text(mediaType == .movie ? "Movies" : "Series")
                    .tag(mediaType)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("search-media-type")
        .padding()
        .background(.background)
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
