//
//  PosterImageLoader.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import Foundation
import UIKit
import MovieCore

/// Both prefetch and visible cards populate the same prepared-image memory cache.
@MainActor
enum PosterImageLoader {
    static func image(for url: URL) async throws -> UIImage {
        try Task.checkCancellation()
        if let image = ImageMemoryCache.shared.image(for: url) { return image }
        let data = try await AppStorage.imageLoader.data(for: url)
        try Task.checkCancellation()
        // Another consumer may have prepared this download while we were waiting.
        if let image = ImageMemoryCache.shared.image(for: url) { return image }
        guard let image = UIImage(data: data),
              let preparedImage = await image.byPreparingForDisplay() else {
            throw URLError(.cannotDecodeContentData)
        }
        try Task.checkCancellation()
        ImageMemoryCache.shared.insert(preparedImage, for: url)
        return preparedImage
    }

    static func warm(_ url: URL) async throws {
        _ = try await image(for: url)
    }
}
