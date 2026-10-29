//
//  SeriesDTO.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

struct SeriesDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let overview: String
    let posterPath: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case overview
        case posterPath = "poster_path"
    }

    func toDomain() -> Movie {
        Movie(
            id: id,
            title: name,
            overview: overview,
            posterPath: posterPath,
            mediaType: .series
        )
    }
}
