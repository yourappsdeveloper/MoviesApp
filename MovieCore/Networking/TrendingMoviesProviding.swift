//
//  TrendingMoviesProviding.swift
//  MoviesApp
//
//  Created by Alex  on 28.10.2026.
//


public protocol TrendingMoviesProviding: Sendable {
    func fetchTrendingMovies() async throws -> [Movie]
}