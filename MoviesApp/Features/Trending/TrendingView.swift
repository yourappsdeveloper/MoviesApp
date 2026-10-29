//
//  TrendingView.swift
//  MoviesApp
//
//  Created by Alex  on 28.10.2026.
//


import SwiftUI
import MovieCore

struct TrendingView: View {
    
    let viewModel: TrendingViewModel
    let movieDetailsProvider: any MovieDetailsProviding

    @State private var retryCount = 0
    @State private var navigationPath: [Int] = []
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            content
                .navigationTitle("Trending")
                .navigationDestination(for: Int.self) { movieID in
                    MovieDetailsView(
                        movieID: movieID,
                        moviesProvider: movieDetailsProvider
                    )
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(
                    AppTheme.navigationBackground,
                    for: .navigationBar
                )
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .tint(AppTheme.accent)
        .task(id: retryCount) {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            loadingView

        case .loaded(let movies):
            if movies.isEmpty {
                emptyView
            } else {
                moviesList(movies)
            }

        case .failed(let message):
            errorView(message: message)
        }
    }

    private var loadingView: some View {
        ProgressView("Loading movies…")
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "No movies found",
            systemImage: "film",
            description: Text("Please check again later.")
        )
    }
    
    @ViewBuilder
    private var paginationFooter: some View {
        switch viewModel.nextPageState {
        case .idle:
            EmptyView()

        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding()
                .background(.background)

        case .failed(let message):
            VStack(spacing: 8) {
                Text(message)
                    .font(.footnote)
                    .multilineTextAlignment(.center)

                Button("Try Again") {
                    Task {
                        await viewModel.retryNextPage()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.background)
        }
    }

    private func moviesList(_ movies: [Movie]) -> some View {
        MoviesCollectionView(
            movies: movies,
            onNearEnd: {
                await viewModel.loadNextPage()
            },
            onSelectMovie: { movie in
                navigationPath.append(movie.id)
            }
        )
        .safeAreaInset(edge: .bottom, spacing: 0) {
            paginationFooter
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                retryCount += 1
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
