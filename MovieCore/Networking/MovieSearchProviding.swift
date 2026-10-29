//
//  MovieSearchProviding.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

public protocol MovieSearchProviding: Sendable {
    func searchMovies(
        query: String,
        page: Int
    ) async throws -> MoviePage
}
