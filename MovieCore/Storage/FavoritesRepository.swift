//
//  FavoritesRepository.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import Foundation

public protocol FavoritesStoring: Sendable {
    func load() async throws -> [Movie]
    func toggle(_ movie: Movie) async throws -> [Movie]
}

/// Reads, modifies, and atomically writes favorites in one actor operation.
/// Favorites are user data and are never evicted with the offline cache.
public actor FavoritesRepository: FavoritesStoring {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> [Movie] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try JSONDecoder().decode([Movie].self, from: Data(contentsOf: fileURL))
    }

    public func toggle(_ movie: Movie) throws -> [Movie] {
        var movies = try load()
        if let index = movies.firstIndex(where: {
            $0.id == movie.id && $0.mediaType == movie.mediaType
        }) {
            movies.remove(at: index)
        } else {
            movies.insert(movie, at: 0)
        }
        let data = try JSONEncoder().encode(movies)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
        return movies
    }
}
