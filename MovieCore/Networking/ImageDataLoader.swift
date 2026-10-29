//
//  ImageDataLoader.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import CoreFoundation
import Foundation
import ImageIO

/// Shares image downloads, cancelling transport only after its last consumer leaves.
public actor ImageDataLoader {
    private typealias Waiter = CheckedContinuation<Data, any Error>

    private struct PendingImage {
        let id: UUID
        let task: Task<Void, Never>
        var waiters: [UUID: Waiter]
    }

    private let cache: DiskDataStore
    private let session: URLSession
    private var inFlight: [URL: PendingImage] = [:]

    public init(cache: DiskDataStore, session: URLSession = .shared) {
        self.cache = cache
        self.session = session
    }

    public func data(for url: URL) async throws -> Data {
        try Task.checkCancellation()
        let consumer = UUID()
        return try await withTaskCancellationHandler {
            let data = try await withCheckedThrowingContinuation { (continuation: Waiter) in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                enqueue(url, consumer: consumer, continuation: continuation)
            }
            try Task.checkCancellation()
            return data
        } onCancel: {
            Task { await self.cancel(url, consumer: consumer) }
        }
    }

    // Internal diagnostics keep cancellation/coalescing tests synchronized with registration.
    func pendingConsumerCount(for url: URL) -> Int {
        inFlight[url]?.waiters.count ?? 0
    }

    private func enqueue(_ url: URL, consumer: UUID, continuation: Waiter) {
        if inFlight[url] != nil {
            inFlight[url]?.waiters[consumer] = continuation
            return
        }
        let identifier = UUID()
        let task = Task { [session, cache] in
            let result: Result<Data, any Error>
            do {
                let data = try await Self.readOrDownload(url, cache: cache, session: session)
                result = .success(data)
            } catch {
                result = .failure(error)
            }
            self.finish(url, identifier: identifier, result: result)
        }
        inFlight[url] = PendingImage(id: identifier, task: task, waiters: [consumer: continuation])
    }

    private func finish(_ url: URL, identifier: UUID, result: Result<Data, any Error>) {
        guard let pending = inFlight[url], pending.id == identifier else { return }
        inFlight[url] = nil
        for waiter in pending.waiters.values { waiter.resume(with: result) }
    }

    private func cancel(_ url: URL, consumer: UUID) {
        guard var pending = inFlight[url], let waiter = pending.waiters.removeValue(forKey: consumer) else { return }
        if pending.waiters.isEmpty {
            inFlight[url] = nil
            pending.task.cancel()
        } else {
            inFlight[url] = pending
        }
        waiter.resume(throwing: CancellationError())
    }

    private static func readOrDownload(_ url: URL, cache: DiskDataStore, session: URLSession) async throws -> Data {
        try Task.checkCancellation()
        if let data = try? await cache.read(key: url.absoluteString) {
            try Task.checkCancellation()
            if isImage(data) { return data }
            try? await cache.remove(key: url.absoluteString)
        }
        try Task.checkCancellation()
        let (data, response) = try await session.data(from: url)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode), isImage(data) else {
            throw URLError(.badServerResponse)
        }
        try? await cache.write(data, key: url.absoluteString)
        try Task.checkCancellation()
        return data
    }

    private static func isImage(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return false }
        return CGImageSourceGetCount(source) > 0
    }
}
