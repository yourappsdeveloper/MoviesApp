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

    @State private var retryCount = 0

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Trending")
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

    private func moviesList(_ movies: [Movie]) -> some View {
        MoviesCollectionView(movies: movies)
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
