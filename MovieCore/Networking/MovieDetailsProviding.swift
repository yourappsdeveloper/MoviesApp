//
//  MovieDetailsProviding.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

public protocol MovieDetailsProviding: Sendable {
    func fetchMovieDetails(id: Int) async throws -> MovieDetails
}
