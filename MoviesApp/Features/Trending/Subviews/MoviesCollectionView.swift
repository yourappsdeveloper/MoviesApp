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

    func makeCoordinator() -> Coordinator {
        Coordinator()
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

        return collectionView
    }

    func updateUIView(
        _ collectionView: UICollectionView,
        context: Context
    ) {
        context.coordinator.movies = movies
        collectionView.reloadData()
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

            let estimatedHeight = cardWidth * 1.5 + 150

            let item = NSCollectionLayoutItem(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .absolute(cardWidth),
                    heightDimension: .estimated(estimatedHeight)
                )
            )

            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(estimatedHeight)
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

    @MainActor
    final class Coordinator: NSObject, UICollectionViewDataSource {
        static let cellIdentifier = "MovieCell"

        var movies: [Movie] = []

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
    }
}
