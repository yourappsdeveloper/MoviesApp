//
//  MovieSearchProviding.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

public protocol MovieSearchProviding: Sendable {
    func search(
        query: String,
        page: Int,
        mediaType: MediaType
    ) async throws -> MoviePage
}
