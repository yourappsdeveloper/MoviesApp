//
//  ImageMemoryCache.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//


import Foundation
import UIKit

/// Keeps decoded images in memory for quick reuse.
@MainActor
final class ImageMemoryCache {
    static let shared = ImageMemoryCache()

    private let storage = NSCache<NSURL, UIImage>()

    private init() {
        storage.totalCostLimit = 64 * 1024 * 1024
        storage.countLimit = 100
    }

    /// Returns an image immediately when it is still cached.
    func image(for url: URL) -> UIImage? {
        storage.object(forKey: url as NSURL)
    }

    /// Stores an image using its decoded bitmap size as the cost.
    func insert(_ image: UIImage, for url: URL) {
        let cost = image.cgImage.map {
            $0.bytesPerRow * $0.height
        } ?? 0

        storage.setObject(image, forKey: url as NSURL, cost: cost)
    }
}