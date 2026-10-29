//
//  AppStorage.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import Foundation
import MovieCore

/// Keeps test persistence separate from the user's favorites and caches.
@MainActor
enum AppStorage {
    static let directory: URL = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-testing") {
            let index = arguments.firstIndex(of: "-ui-test-storage")
            let supplied = index.flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
            let identifier = supplied.flatMap(UUID.init(uuidString:)) ?? UUID()
            return FileManager.default.temporaryDirectory
                .appendingPathComponent("MoviesAppUITests/\(identifier.uuidString)")
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MoviesApp")
    }()

    static let imagePrefetcher = ImagePrefetcher { url in
        try await PosterImageLoader.warm(url)
    }

    static let imageLoader = ImageDataLoader(
        cache: DiskDataStore(directory: directory.appendingPathComponent("Images"))
    )
}
