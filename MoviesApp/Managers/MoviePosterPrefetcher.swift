//
//  MoviePosterPrefetcher.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import MovieCore
import UIKit

/// Converts UIKit's prefetch callbacks into one owner's URL demand in the shared queue.
@MainActor
final class MoviePosterPrefetcher {
    private struct Geometry: Equatable {
        let width: CGFloat
        let scale: CGFloat
        let usesLargeText: Bool
    }

    private let owner = UUID()
    private let prefetcher: ImagePrefetcher
    private var requested: [IndexPath: URL] = [:]
    private var geometry: Geometry?
    private var updateTask: Task<Void, Never>?

    init(prefetcher: ImagePrefetcher) {
        self.prefetcher = prefetcher
    }

    func updateLayout(in collectionView: UICollectionView) {
        let insets = collectionView.adjustedContentInset
        let current = Geometry(
            width: collectionView.bounds.width - insets.left - insets.right,
            scale: collectionView.traitCollection.displayScale,
            usesLargeText: collectionView.traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        )
        guard geometry != current else { return }
        geometry = current
        requested.removeAll()
        submit()
    }

    func prefetch(_ indexPaths: [IndexPath], movies: [Movie], in collectionView: UICollectionView) {
        updateLayout(in: collectionView)
        guard let geometry, geometry.width > 0, geometry.scale > 0 else { return }
        let fallbackWidth = MovieGridLayout.cardWidth(
            containerWidth: geometry.width, usesLargeText: geometry.usesLargeText
        )
        for indexPath in indexPaths where indexPath.section == 0 && movies.indices.contains(indexPath.item) {
            let width = collectionView.layoutAttributesForItem(at: indexPath)?.size.width ?? fallbackWidth
            requested[indexPath] = TMDBImageURL.poster(
                path: movies[indexPath.item].posterPath, width: Double(width), scale: Double(geometry.scale)
            )
        }
        submit()
    }

    func cancel(_ indexPaths: [IndexPath]) {
        for indexPath in indexPaths { requested[indexPath] = nil }
        submit()
    }

    func reset() {
        geometry = nil
        requested.removeAll()
        submit()
    }

    private func submit() {
        updateTask?.cancel()
        let urls = requested.keys.sorted().compactMap { requested[$0] }
        let owner = owner
        let prefetcher = prefetcher
        updateTask = Task { await prefetcher.update(urls, for: owner) }
    }
}
