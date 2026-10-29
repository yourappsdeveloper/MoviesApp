//
//  TMDBClient.swift
//  MoviesApp
//
//  Created by Alex  on 28.10.2026.
//

import Foundation

public struct TMDBClient: TrendingMoviesProviding, MovieDetailsProviding, MovieSearchProviding {

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

    /// Loads movie details using the shared implementation.
    public func fetchMovieDetails(
        id: Int
    ) async throws -> MovieDetails {
        try await fetchDetails(
            id: id,
            mediaType: .movie
        )
    }

    /// Loads details using the selected movie or TV namespace.
    public func fetchDetails(
        id: Int,
        mediaType: MediaType
    ) async throws -> MovieDetails {
        guard id > 0 else {
            throw TMDBError.invalidMovieID
        }

        let path = "\(mediaType.rawValue)/\(id)"

        switch mediaType {
        case .movie:
            let dto: MovieDetailsDTO = try await fetch(
                path: path
            )
            return dto.toDomain()

        case .series:
            let dto: SeriesDetailsDTO = try await fetch(
                path: path
            )
            return dto.toDomain()
        }
    }

    /// Searches movies using the shared media search implementation.
    public func searchMovies(
        query: String,
        page: Int
    ) async throws -> MoviePage {
        try await search(
            query: query,
            page: page,
            mediaType: .movie
        )
    }

    /// Searches the selected content type and returns one page.
    public func search(
        query: String,
        page: Int,
        mediaType: MediaType
    ) async throws -> MoviePage {
        let trimmedQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedQuery.isEmpty else {
            throw TMDBError.emptySearchQuery
        }

        guard page > 0 else {
            throw TMDBError.invalidPage
        }

        let queryItems = [
            URLQueryItem(name: "query", value: trimmedQuery),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "include_adult", value: "false")
        ]
        let path = "search/\(mediaType.rawValue)"

        switch mediaType {
        case .movie:
            let result: PaginatedResponse<MovieDTO> = try await fetch(
                path: path,
                queryItems: queryItems
            )

            return MoviePage(
                page: result.page,
                totalPages: result.totalPages,
                movies: result.results.map { $0.toDomain() }
            )

        case .series:
            let result: PaginatedResponse<SeriesDTO> = try await fetch(
                path: path,
                queryItems: queryItems
            )

            return MoviePage(
                page: result.page,
                totalPages: result.totalPages,
                movies: result.results.map { $0.toDomain() }
            )
        }
    }

    /// Performs an authenticated request and decodes its response.
    private func fetch<Response: Decodable & Sendable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        try Task.checkCancellation()

        guard var components = URLComponents(
            string: "https://api.themoviedb.org/3/\(path)"
        ) else {
            throw TMDBError.invalidURL
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

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

        return try JSONDecoder().decode(Response.self, from: data)
    }
}

public enum TMDBError: Error {
    case invalidURL
    case invalidMovieID
    case emptySearchQuery
    case invalidPage
    case invalidResponse
    case httpStatus(Int)
}
