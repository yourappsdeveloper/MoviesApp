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
            collectionViewLayout: Self.makeLayout()
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

        return collectionView
    }

    func updateUIView(
        _ collectionView: UICollectionView,
        context: Context
    ) {
        let coordinator = context.coordinator
        coordinator.onNearEnd = onNearEnd
        coordinator.onSelectMovie = onSelectMovie

        guard coordinator.movies != movies else {
            return
        }

        let oldCount = coordinator.movies.count

        let isAppending = movies.count > oldCount
            && coordinator.movies.elementsEqual(movies.prefix(oldCount))

        guard isAppending, oldCount > 0 else {
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

    /// Adapts the column count to the available width and text size.
    private static func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { _, environment in
            let inset: CGFloat = 16
            let spacing: CGFloat = 12

            let availableWidth = max(
                1,
                environment.container.effectiveContentSize.width - inset * 2
            )

            let usesLargeText = environment.traitCollection
                .preferredContentSizeCategory.isAccessibilityCategory

            let columns = usesLargeText
                ? 1
                : max(1, Int((availableWidth + spacing) / (160 + spacing)))

            let cardWidth = (
                availableWidth - spacing * CGFloat(columns - 1)
            ) / CGFloat(columns)

            let textHeight = UIFontMetrics(forTextStyle: .subheadline)
                .scaledValue(
                    for: 150,
                    compatibleWith: environment.traitCollection
                )

            let cardHeight = cardWidth * 1.5 + textHeight

            let item = NSCollectionLayoutItem(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .absolute(cardWidth),
                    heightDimension: .estimated(cardHeight)
                )
            )

            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(cardHeight)
                ),
                repeatingSubitem: item,
                count: columns
            )
            group.interItemSpacing = .fixed(spacing)

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = spacing
            section.contentInsets = NSDirectionalEdgeInsets(
                top: inset,
                leading: inset,
                bottom: inset,
                trailing: inset
            )

            return section
        }
    }

    /// Cancels pagination when the collection view is removed.
    static func dismantleUIView(
        _ collectionView: UICollectionView,
        coordinator: Coordinator
    ) {
        coordinator.paginationTask?.cancel()
        collectionView.delegate = nil
        collectionView.dataSource = nil
    }

    @MainActor
    final class Coordinator: NSObject,
                             UICollectionViewDataSource,
                             UICollectionViewDelegate {

        static let cellIdentifier = "MovieCell"

        var movies: [Movie] = []
        var onNearEnd: @MainActor () async -> Void
        var paginationTask: Task<Void, Never>?
        var onSelectMovie: @MainActor (Movie) -> Void

        init(
            onNearEnd: @escaping @MainActor () async -> Void,
            onSelectMovie: @escaping @MainActor (Movie) -> Void
        ) {
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

            cell.contentConfiguration = UIHostingConfiguration {
                MovieCardView(movie: movie)
                    .id(movie.id)
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
