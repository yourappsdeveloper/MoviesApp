//
//  TMDBClient.swift
//  MoviesApp
//
//  Created by Alex  on 28.10.2026.
//


import Foundation

public struct TMDBClient: TrendingMoviesProviding, MovieDetailsProviding {
    
    private let token: String
    private let session: URLSession
    
    public init(
        token: String,
        session: URLSession = .shared
    ) {
        self.token = token
        self.session = session
    }
    
    /// Loads the first page for callers that only need the movie list.
    public func fetchTrendingMovies() async throws -> [Movie] {
        let result = try await fetchTrendingMovies(page: 1)
        return result.movies
    }
    
    /// Loads a specific page and preserves its pagination information.
    public func fetchTrendingMovies(page: Int) async throws -> MoviePage {
        guard page > 0 else {
            throw TMDBError.invalidPage
        }
        
        guard var components = URLComponents(
            string: "https://api.themoviedb.org/3/trending/movie/day"
        ) else {
            throw TMDBError.invalidURL
        }
        
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page))
        ]
        
        guard let url = components.url else {
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
        
        let result = try JSONDecoder().decode(
            PaginatedResponse<MovieDTO>.self,
            from: data
        )
        
        return MoviePage(
            page: result.page,
            totalPages: result.totalPages,
            movies: result.results.map { $0.toDomain() }
        )
    }
    
    public func fetchMovieDetails(id: Int) async throws -> MovieDetails {
        guard id > 0 else {
            throw TMDBError.invalidMovieID
        }

        try Task.checkCancellation()

        guard let url = URL(
            string: "https://api.themoviedb.org/3/movie/\(id)"
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

        let dto = try JSONDecoder().decode(
            MovieDetailsDTO.self,
            from: data
        )

        return dto.toDomain()
    }
}

public enum TMDBError: Error {
    case invalidURL
    case invalidMovieID
    case invalidPage
    case invalidResponse
    case httpStatus(Int)
}
