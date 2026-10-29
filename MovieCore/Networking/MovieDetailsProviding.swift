//
//  MovieDetailsProviding.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

public protocol MovieDetailsProviding: Sendable {
    func fetchDetails(
        id: Int,
        mediaType: MediaType
    ) async throws -> MovieDetails
}
