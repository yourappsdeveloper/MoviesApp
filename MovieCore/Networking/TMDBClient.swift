//
//  TMDBClient.swift
//  MoviesApp
//
//  Created by Alex  on 28.10.2026.
//


import Foundation

public struct TMDBClient: TrendingMoviesProviding {
    private let token: String
    private let session: URLSession

    public init(
        token: String,
        session: URLSession = .shared
    ) {
        self.token = token
        self.session = session
    }

    public func fetchTrendingMovies() async throws -> [Movie] {
        guard let url = URL(
            string: "https://api.themoviedb.org/3/trending/movie/day"
        ) else {
            throw TMDBError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue(
            "Bearer \(token)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) = try await session.data(for: request)

        guard let response = response as? HTTPURLResponse else {
            throw TMDBError.invalidResponse
        }

        guard (200..<300).contains(response.statusCode) else {
            throw TMDBError.httpStatus(response.statusCode)
        }

        try Task.checkCancellation()

        let page = try JSONDecoder().decode(
            PaginatedResponse<MovieDTO>.self,
            from: data
        )

        return page.results.map { $0.toDomain() }
    }
}

public enum TMDBError: Error {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
}
