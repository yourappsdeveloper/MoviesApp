//
//  MoviePosterPrefetcherTests.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import MovieCore
import UIKit
import XCTest
@testable import MoviesApp

@MainActor
final class MoviePosterPrefetcherTests: XCTestCase {
    private func collection(dataSource: PosterTestDataSource) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 170, height: 300)
        layout.estimatedItemSize = .zero
        let collection = UICollectionView(frame: CGRect(x: 0, y: 0, width: 400, height: 800),
                                          collectionViewLayout: layout)
        collection.contentInsetAdjustmentBehavior = .never
        collection.traitOverrides.preferredContentSizeCategory = .large
        collection.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "TestCell")
        collection.dataSource = dataSource
        collection.reloadData()
        collection.layoutIfNeeded()
        return collection
    }

    private func movie(id: Int = 1, path: String? = "/poster.jpg") -> Movie {
        Movie(id: id, title: "Prefetch", overview: "Overview", posterPath: path)
    }

    func testUIKitPrefetchUsesActualCellWidthAndSkipsMissingOrInvalidItems() async throws {
        let started = expectation(description: "Poster at displayed resolution")
        let dataSource = PosterTestDataSource(count: 2)
        defer { withExtendedLifetime(dataSource) {} }
        let view = collection(dataSource: dataSource)
        let attributes = try XCTUnwrap(view.layoutAttributesForItem(at: IndexPath(item: 0, section: 0)))
        XCTAssertEqual(attributes.size.width, 170, accuracy: 0.001)
        let scale = view.traitCollection.displayScale
        XCTAssertGreaterThan(scale, 0)
        let expected = try XCTUnwrap(TMDBImageURL.poster(path: "/poster.jpg", width: 170, scale: Double(scale)))
        let queue = ImagePrefetcher { url in
            XCTAssertEqual(url, expected)
            started.fulfill()
        }
        let controller = MoviePosterPrefetcher(prefetcher: queue)
        let coordinator = MoviesCollectionView.Coordinator(
            onNearEnd: {}, onSelectMovie: { _ in }, posterPrefetcher: controller
        )
        coordinator.movies = [movie(), movie(id: 2, path: nil)]
        coordinator.collectionView(view, prefetchItemsAt: [
            IndexPath(item: 0, section: 0), IndexPath(item: 1, section: 0), IndexPath(item: 99, section: 0)
        ])
        await fulfillment(of: [started], timeout: 2)
        controller.reset()
    }

    func testUIKitCancellationStopsAnUnneededPoster() async {
        let started = expectation(description: "Poster started")
        let stopped = expectation(description: "Poster cancelled")
        let probe = PosterPrefetchProbe(onStart: { _ in started.fulfill() }, onCancel: { _ in stopped.fulfill() })
        let queue = ImagePrefetcher { try await probe.load($0) }
        let controller = MoviePosterPrefetcher(prefetcher: queue)
        let coordinator = MoviesCollectionView.Coordinator(
            onNearEnd: {}, onSelectMovie: { _ in }, posterPrefetcher: controller
        )
        coordinator.movies = [movie()]
        let dataSource = PosterTestDataSource(count: 1)
        defer { withExtendedLifetime(dataSource) {} }
        let view = collection(dataSource: dataSource)
        let indexPath = IndexPath(item: 0, section: 0)
        coordinator.collectionView(view, prefetchItemsAt: [indexPath])
        await fulfillment(of: [started], timeout: 2)
        coordinator.collectionView(view, cancelPrefetchingForItemsAt: [indexPath])
        await fulfillment(of: [stopped], timeout: 2)
        await probe.finishAll()
    }

    func testResetCancelsRequestsWhenCollectionIsReplacedOrDismissed() async {
        let started = expectation(description: "Poster started")
        let stopped = expectation(description: "Poster reset")
        let probe = PosterPrefetchProbe(onStart: { _ in started.fulfill() }, onCancel: { _ in stopped.fulfill() })
        let queue = ImagePrefetcher { try await probe.load($0) }
        let controller = MoviePosterPrefetcher(prefetcher: queue)
        let dataSource = PosterTestDataSource(count: 1)
        defer { withExtendedLifetime(dataSource) {} }
        let view = collection(dataSource: dataSource)
        controller.prefetch([IndexPath(item: 0, section: 0)], movies: [movie()], in: view)
        await fulfillment(of: [started], timeout: 2)
        controller.reset()
        await fulfillment(of: [stopped], timeout: 2)
        await probe.finishAll()
    }

    func testSizeChangeCancelsOldResolutionAndRequestsNewResolution() async throws {
        let first = expectation(description: "Initial resolution")
        let second = expectation(description: "New resolution")
        let stopped = expectation(description: "Old resolution cancelled")
        let dataSource = PosterTestDataSource(count: 1)
        defer { withExtendedLifetime(dataSource) {} }
        let view = collection(dataSource: dataSource)
        let attributes = try XCTUnwrap(view.layoutAttributesForItem(at: IndexPath(item: 0, section: 0)))
        XCTAssertEqual(attributes.size.width, 170, accuracy: 0.001)
        let scale = Double(view.traitCollection.displayScale)
        XCTAssertGreaterThan(scale, 0)
        let oldURL = try XCTUnwrap(TMDBImageURL.poster(path: "/poster.jpg", width: 170, scale: scale))
        let newURL = try XCTUnwrap(TMDBImageURL.poster(path: "/poster.jpg", width: 300, scale: scale))
        XCTAssertNotEqual(oldURL, newURL)
        let probe = PosterPrefetchProbe(onStart: { url in
            if url == oldURL { first.fulfill() }
            if url == newURL { second.fulfill() }
        }, onCancel: { url in
            if url == oldURL { stopped.fulfill() }
        })
        let queue = ImagePrefetcher { try await probe.load($0) }
        let controller = MoviePosterPrefetcher(prefetcher: queue)
        let indices = [IndexPath(item: 0, section: 0)]
        controller.prefetch(indices, movies: [movie()], in: view)
        await fulfillment(of: [first], timeout: 2)
        view.frame.size.width = 800
        let layout = try XCTUnwrap(view.collectionViewLayout as? UICollectionViewFlowLayout)
        layout.itemSize.width = 300
        layout.invalidateLayout()
        view.layoutIfNeeded()
        let resized = try XCTUnwrap(view.layoutAttributesForItem(at: IndexPath(item: 0, section: 0)))
        XCTAssertEqual(resized.size.width, 300, accuracy: 0.001)
        controller.prefetch(indices, movies: [movie()], in: view)
        await fulfillment(of: [second, stopped], timeout: 2)
        controller.reset()
        await probe.finishAll()
    }

    func testGridUsesOneColumnForAccessibilityTextSizes() {
        XCTAssertEqual(MovieGridLayout.cardWidth(containerWidth: 400, usesLargeText: true), 368)
        XCTAssertEqual(MovieGridLayout.cardWidth(containerWidth: 400, usesLargeText: false), 178)
    }

    func testGridAdaptsToWideLandscapeContainer() {
        XCTAssertEqual(MovieGridLayout.cardWidth(containerWidth: 852, usesLargeText: false), 196)
    }
}

@MainActor
private final class PosterTestDataSource: NSObject, UICollectionViewDataSource {
    let count: Int
    init(count: Int) {
        self.count = count
        super.init()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { count }

    func collectionView(
        _ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        collectionView.dequeueReusableCell(withReuseIdentifier: "TestCell", for: indexPath)
    }
}

private actor PosterPrefetchProbe {
    private let onStart: @Sendable (URL) -> Void
    private let onCancel: @Sendable (URL) -> Void
    private var pending: [URL: CheckedContinuation<Void, any Error>] = [:]

    init(onStart: @escaping @Sendable (URL) -> Void, onCancel: @escaping @Sendable (URL) -> Void) {
        self.onStart = onStart
        self.onCancel = onCancel
    }

    func load(_ url: URL) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                pending[url] = continuation
                onStart(url)
            }
        } onCancel: {
            Task { await self.cancel(url) }
        }
    }

    private func cancel(_ url: URL) {
        guard let continuation = pending.removeValue(forKey: url) else { return }
        continuation.resume(throwing: CancellationError())
        onCancel(url)
    }

    func finishAll() {
        let values = Array(pending.values)
        pending.removeAll()
        for value in values { value.resume() }
    }
}
