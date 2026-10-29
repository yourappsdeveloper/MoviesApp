//
//  MovieDetails.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

public struct MovieDetails: Identifiable, Codable, Sendable {
    public var isFromCache = false
    public let id: Int
    public let title: String
    public let overview: String
    public let posterPath: String?
    public let backdropPath: String?
    public let releaseDate: String?
    public let runtime: Int?
    public let voteAverage: Double
    public let voteCount: Int
    public let mediaType: MediaType
    public let numberOfSeasons: Int?
    public let numberOfEpisodes: Int?

    public init(
        id: Int,
        title: String,
        overview: String,
        posterPath: String?,
        backdropPath: String?,
        releaseDate: String?,
        runtime: Int?,
        voteAverage: Double,
        voteCount: Int,
        mediaType: MediaType = .movie,
        numberOfSeasons: Int? = nil,
        numberOfEpisodes: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.overview = overview
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.releaseDate = releaseDate
        self.runtime = runtime
        self.voteAverage = voteAverage
        self.voteCount = voteCount
        self.mediaType = mediaType
        self.numberOfSeasons = numberOfSeasons
        self.numberOfEpisodes = numberOfEpisodes
    }
}
