//
//  MoviePage.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

/// A page of movies and the information needed to load the next one.
public struct MoviePage: Codable, Sendable {
    public var isFromCache = false
    public let page: Int
    public let totalPages: Int
    public let movies: [Movie]

    public init(page: Int, totalPages: Int, movies: [Movie]) {
        self.page = page
        self.totalPages = totalPages
        self.movies = movies
    }
}
