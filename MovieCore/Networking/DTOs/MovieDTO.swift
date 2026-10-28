//
//  MovieDTO.swift
//  MoviesApp
//
//  Created by Alex  on 28.10.2026.
//


import Foundation

struct MovieDTO: Decodable, Sendable {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case posterPath = "poster_path"
    }
}