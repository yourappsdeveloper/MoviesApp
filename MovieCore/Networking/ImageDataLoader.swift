//
//  ImageDataLoader.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import CoreFoundation
import Foundation
import ImageIO

/// Reuses disk images across launches and coalesces simultaneous URL requests.
public actor ImageDataLoader {
    private let cache: DiskDataStore
    private let session: URLSession
    private var inFlight: [URL: PendingImage] = [:]

    private struct PendingImage {
        let id = UUID()
        let task: Task<Data, any Error>
    }

    public init(cache: DiskDataStore, session: URLSession = .shared) {
        self.cache = cache
        self.session = session
    }

    public func data(for url: URL) async throws -> Data {
        try Task.checkCancellation()
        if let data = try? await cache.read(key: url.absoluteString) {
            try Task.checkCancellation()
            if Self.isImage(data) { return data }
            try? await cache.remove(key: url.absoluteString)
        }
        let pending: PendingImage
        if let existing = inFlight[url] {
            pending = existing
        } else {
            let session = session
            let cache = cache
            pending = PendingImage(task: Task {
                let (data, response) = try await session.data(from: url)
                guard let response = response as? HTTPURLResponse,
                      (200..<300).contains(response.statusCode), Self.isImage(data) else {
                    throw URLError(.badServerResponse)
                }
                try? await cache.write(data, key: url.absoluteString)
                return data
            })
            inFlight[url] = pending
        }
        defer {
            if inFlight[url]?.id == pending.id { inFlight[url] = nil }
        }
        let data = try await pending.task.value
        try Task.checkCancellation()
        return data
    }

    private static func isImage(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return false }
        return CGImageSourceGetCount(source) > 0
    }
}
