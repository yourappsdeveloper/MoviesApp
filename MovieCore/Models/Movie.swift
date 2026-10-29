//
//  Movie.swift
//  MoviesApp
//
//  Created by Alex  on 28.10.2026.
//

public struct Movie: Identifiable, Codable, Sendable, Hashable {
    public let id: Int
    public let title: String
    public let overview: String
    public let posterPath: String?
    public let mediaType: MediaType

    public init(
        id: Int,
        title: String,
        overview: String,
        posterPath: String?,
        mediaType: MediaType = .movie
    ) {
        self.id = id
        self.title = title
        self.overview = overview
        self.posterPath = posterPath
        self.mediaType = mediaType
    }
}
