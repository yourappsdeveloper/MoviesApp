//
//  SeriesDetailsDTO.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import Foundation

/// Maps TV details to the shared details model.
struct SeriesDetailsDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let firstAirDate: String?
    let episodeRunTime: [Int]?
    let voteAverage: Double
    let voteCount: Int
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case firstAirDate = "first_air_date"
        case episodeRunTime = "episode_run_time"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
    }

    func toDomain() -> MovieDetails {
        MovieDetails(
            id: id,
            title: name,
            overview: overview,
            posterPath: posterPath,
            backdropPath: backdropPath,
            releaseDate: firstAirDate,
            runtime: episodeRunTime?.first(where: { $0 > 0 }),
            voteAverage: voteAverage,
            voteCount: voteCount,
            mediaType: .series,
            numberOfSeasons: numberOfSeasons,
            numberOfEpisodes: numberOfEpisodes
        )
    }
}
