//
//  MovieDetailsDTO.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//


import Foundation

struct MovieDetailsDTO: Decodable, Sendable {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let runtime: Int?
    let voteAverage: Double
    let voteCount: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case runtime
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
    }

    func toDomain() -> MovieDetails {
        MovieDetails(
            id: id,
            title: title,
            overview: overview,
            posterPath: posterPath,
            backdropPath: backdropPath,
            releaseDate: releaseDate,
            runtime: runtime,
            voteAverage: voteAverage,
            voteCount: voteCount
        )
    }
}