//
//  CachedPosterView.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//


import Foundation
import SwiftUI
import UIKit

/// Displays cached posters immediately and downloads missing ones.
@MainActor
struct CachedPosterView: View {
    let url: URL?

    @State private var loadedPoster: (url: URL, image: UIImage)?

    private let cache = ImageMemoryCache.shared

    var body: some View {
        ZStack {
            if let image = displayedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .task(id: url) {
            await load()
        }
    }

    private var displayedImage: UIImage? {
        guard let url else {
            return nil
        }

        if let image = cache.image(for: url) {
            return image
        }

        guard loadedPoster?.url == url else {
            return nil
        }

        return loadedPoster?.image
    }

    private var placeholder: some View {
        Image(systemName: "photo")
            .font(.system(size: 32))
            .foregroundStyle(.secondary)
    }

    /// Downloads and prepares the poster only when it is not cached.
    private func load() async {
        guard let url,
              cache.image(for: url) == nil,
              !Task.isCancelled else {
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(
                from: url
            )

            guard let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode),
                  let image = UIImage(data: data) else {
                return
            }

            try Task.checkCancellation()

            guard let preparedImage = await image.byPreparingForDisplay() else {
                return
            }

            try Task.checkCancellation()

            cache.insert(preparedImage, for: url)
            loadedPoster = (url: url, image: preparedImage)
        } catch {
            // Keep the placeholder if loading fails or is cancelled.
        }
    }
}