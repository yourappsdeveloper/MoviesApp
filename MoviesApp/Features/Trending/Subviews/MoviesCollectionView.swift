//
//  MoviesCollectionView.swift
//  MoviesApp
//
//  Created by Alex  on 28.10.2026.
//


import SwiftUI
import UIKit
import MovieCore

struct MoviesCollectionView: UIViewRepresentable {
    let movies: [Movie]

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UICollectionView {
        let configuration = UICollectionLayoutListConfiguration(
            appearance: .plain
        )
        let layout = UICollectionViewCompositionalLayout.list(
            using: configuration
        )

        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )

        collectionView.register(
            UICollectionViewListCell.self,
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

    @MainActor
    final class Coordinator: NSObject, UICollectionViewDataSource {
        static let cellIdentifier = "MovieCell"

        var movies: [Movie] = []

        func collectionView(
            _ collectionView: UICollectionView,
            numberOfItemsInSection section: Int
        ) -> Int {
            movies.count
        }

        func collectionView(
            _ collectionView: UICollectionView,
            cellForItemAt indexPath: IndexPath
        ) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: Self.cellIdentifier,
                for: indexPath
            )
            let movie = movies[indexPath.item]

            var content = UIListContentConfiguration.subtitleCell()
            content.text = movie.title
            content.secondaryText = movie.overview
            content.textProperties.numberOfLines = 2
            content.secondaryTextProperties.numberOfLines = 3

            cell.contentConfiguration = content

            return cell
        }
    }
}