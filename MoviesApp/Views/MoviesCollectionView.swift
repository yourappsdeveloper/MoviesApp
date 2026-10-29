//
//  MoviesCollectionView.swift
//  MoviesApp
//
//  Created by Alex  on 28.10.2026.
//

import SwiftUI
import UIKit
import MovieCore

/// Displays SwiftUI movie cards inside a UIKit collection view.
struct MoviesCollectionView: UIViewRepresentable {

    @Environment(FavoritesViewModel.self) private var favorites
    let movies: [Movie]
    let onNearEnd: @MainActor () async -> Void
    let onSelectMovie: @MainActor (Movie) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onNearEnd: onNearEnd,
            onSelectMovie: onSelectMovie
        )
    }

    func makeUIView(context: Context) -> UICollectionView {
        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: MovieGridLayout.make()
        )

        collectionView.backgroundColor = .systemBackground
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false

        collectionView.register(
            UICollectionViewCell.self,
            forCellWithReuseIdentifier: Coordinator.cellIdentifier
        )
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.prefetchDataSource = context.coordinator
        collectionView.isPrefetchingEnabled = true

        return collectionView
    }

    func updateUIView(
        _ collectionView: UICollectionView,
        context: Context
    ) {
        let coordinator = context.coordinator
        coordinator.favorites = favorites
        coordinator.onNearEnd = onNearEnd
        coordinator.onSelectMovie = onSelectMovie
        coordinator.posterPrefetcher.updateLayout(in: collectionView)

        guard coordinator.movies != movies else {
            return
        }

        let oldCount = coordinator.movies.count

        let isAppending = movies.count > oldCount
            && coordinator.movies.elementsEqual(movies.prefix(oldCount))

        guard isAppending, oldCount > 0 else {
            coordinator.posterPrefetcher.reset()
            coordinator.movies = movies
            collectionView.reloadData()
            return
        }

        let newIndexPaths = (oldCount..<movies.count).map {
            IndexPath(item: $0, section: 0)
        }

        UIView.performWithoutAnimation {
            collectionView.performBatchUpdates {
                coordinator.movies = movies
                collectionView.insertItems(at: newIndexPaths)
            }
        }
    }

    /// Cancels pagination and prefetch work when the collection view is removed.
    static func dismantleUIView(
        _ collectionView: UICollectionView,
        coordinator: Coordinator
    ) {
        coordinator.paginationTask?.cancel()
        coordinator.posterPrefetcher.reset()
        collectionView.prefetchDataSource = nil
        collectionView.delegate = nil
        collectionView.dataSource = nil
    }

    @MainActor
    final class Coordinator: NSObject,
                             UICollectionViewDataSource,
                             UICollectionViewDelegate,
                             UICollectionViewDataSourcePrefetching {

        static let cellIdentifier = "MovieCell"

        let posterPrefetcher: MoviePosterPrefetcher
        var favorites: FavoritesViewModel?
        var movies: [Movie] = []
        var onNearEnd: @MainActor () async -> Void
        var paginationTask: Task<Void, Never>?
        var onSelectMovie: @MainActor (Movie) -> Void

        init(
            onNearEnd: @escaping @MainActor () async -> Void,
            onSelectMovie: @escaping @MainActor (Movie) -> Void,
            posterPrefetcher: MoviePosterPrefetcher = MoviePosterPrefetcher(prefetcher: AppStorage.imagePrefetcher)
        ) {
            self.posterPrefetcher = posterPrefetcher
            self.onNearEnd = onNearEnd
            self.onSelectMovie = onSelectMovie
            super.init()
        }

        /// Returns the number of movies currently displayed.
        func collectionView(
            _ collectionView: UICollectionView,
            numberOfItemsInSection section: Int
        ) -> Int {
            movies.count
        }

        /// Reuses a UIKit cell and fills it with a SwiftUI movie card.
        func collectionView(
            _ collectionView: UICollectionView,
            cellForItemAt indexPath: IndexPath
        ) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: Self.cellIdentifier,
                for: indexPath
            )
            let movie = movies[indexPath.item]

            let favorites = favorites
            cell.contentConfiguration = UIHostingConfiguration {
                if let favorites {
                    MovieCardView(movie: movie)
                        .environment(favorites)
                        .id(movie)
                }
            }
            .margins(.all, 0)

            return cell
        }

        /// Starts loading before the user reaches the last few cards.
        func collectionView(
            _ collectionView: UICollectionView,
            willDisplay cell: UICollectionViewCell,
            forItemAt indexPath: IndexPath
        ) {
            posterPrefetcher.updateLayout(in: collectionView)
            guard indexPath.item >= max(0, movies.count - 6),
                  paginationTask == nil else {
                return
            }

            paginationTask = Task { [weak self] in
                guard let self else {
                    return
                }

                await onNearEnd()
                paginationTask = nil
            }
        }

        func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
            posterPrefetcher.prefetch(indexPaths, movies: movies, in: collectionView)
        }

        func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
            posterPrefetcher.cancel(indexPaths)
        }

        // Opens the movie selected by the user.
        func collectionView(
            _ collectionView: UICollectionView,
            didSelectItemAt indexPath: IndexPath
        ) {
            collectionView.deselectItem(at: indexPath, animated: false)
            onSelectMovie(movies[indexPath.item])
        }
    }
}
