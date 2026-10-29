//
//  OfflineMoviesProvider.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import Foundation

/// Keeps the existing provider contracts and tries the network before saved data.
public struct OfflineMoviesProvider: TrendingMoviesProviding, MovieSearchProviding, MovieDetailsProviding {
    private let upstream: any TrendingMoviesProviding & MovieSearchProviding & MovieDetailsProviding
    private let cache: DiskDataStore
    private let usesNetwork: Bool

    public init(
        upstream: any TrendingMoviesProviding & MovieSearchProviding & MovieDetailsProviding,
        cache: DiskDataStore,
        usesNetwork: Bool = true
    ) {
        self.upstream = upstream
        self.cache = cache
        self.usesNetwork = usesNetwork
    }

    public func fetchTrendingMovies(page: Int) async throws -> MoviePage {
        guard page > 0 else { throw TMDBError.invalidPage }
        return try await response(key: "v1/trending/\(page)") {
            try await upstream.fetchTrendingMovies(page: page)
        }
    }

    public func search(query: String, page: Int, mediaType: MediaType) async throws -> MoviePage {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { throw TMDBError.emptySearchQuery }
        guard page > 0 else { throw TMDBError.invalidPage }
        // JSON encoding keeps query delimiters and namespace boundaries unambiguous.
        let key = try JSONEncoder().encode(["v1/search", mediaType.rawValue, String(page), query])
        return try await response(key: key.base64EncodedString()) {
            try await upstream.search(query: query, page: page, mediaType: mediaType)
        }
    }

    public func fetchDetails(id: Int, mediaType: MediaType) async throws -> MovieDetails {
        guard id > 0 else { throw TMDBError.invalidMovieID }
        return try await response(key: "v1/details/\(mediaType.rawValue)/\(id)") {
            try await upstream.fetchDetails(id: id, mediaType: mediaType)
        }
    }

    private func response<Value: Codable & Sendable & OfflineResponse>(
        key: String, fetch: @Sendable () async throws -> Value
    ) async throws -> Value {
        try Task.checkCancellation()
        if !usesNetwork {
            guard let data = try await cache.read(key: key) else { throw URLError(.resourceUnavailable) }
            var value = try JSONDecoder().decode(Value.self, from: data)
            try Task.checkCancellation()
            value.isFromCache = true
            return value
        }
        do {
            let value = try await fetch()
            try Task.checkCancellation()
            if let data = try? JSONEncoder().encode(value) {
                try? await cache.write(data, key: key)
            }
            try Task.checkCancellation()
            return value
        } catch {
            try Task.checkCancellation()
            guard Self.isConnectivityError(error),
                  let data = try? await cache.read(key: key),
                  var value = try? JSONDecoder().decode(Value.self, from: data) else {
                throw error
            }
            try Task.checkCancellation()
            value.isFromCache = true
            return value
        }
    }

    private static func isConnectivityError(_ error: any Error) -> Bool {
        guard let error = error as? URLError else { return false }
        return [.notConnectedToInternet, .networkConnectionLost, .timedOut,
                .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
                .internationalRoamingOff, .dataNotAllowed].contains(error.code)
    }
}

private protocol OfflineResponse {
    var isFromCache: Bool { get set }
}

extension MoviePage: OfflineResponse {}
extension MovieDetails: OfflineResponse {}
