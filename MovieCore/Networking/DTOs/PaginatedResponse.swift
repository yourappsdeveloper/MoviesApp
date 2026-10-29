//
//  PaginatedResponse.swift
//  MoviesApp
//
//  Created by Alex  on 28.10.2026.
//

struct PaginatedResponse<Item: Decodable & Sendable>: Decodable, Sendable {
    let page: Int
    let results: [Item]
    let totalPages: Int
    let totalResults: Int

    private enum CodingKeys: String, CodingKey {
        case page
        case results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}
