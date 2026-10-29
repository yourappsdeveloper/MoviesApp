//
//  TrendingMoviesProviding.swift
//  MoviesApp
//
//  Created by Alex  on 28.10.2026.
//

/// Loads a specific page of trending movies.
public protocol TrendingMoviesProviding: Sendable {
    func fetchTrendingMovies(page: Int) async throws -> MoviePage
}
