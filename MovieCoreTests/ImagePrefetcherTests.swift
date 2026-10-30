//
//  ImagePrefetcherTests.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import Foundation
import XCTest
@testable import MovieCore

final class ImagePrefetcherTests: XCTestCase {
    private func url(_ name: String) throws -> URL {
        try XCTUnwrap(URL(string: "https://images.example.test/\(name)"))
    }

    func testQueueLimitsConcurrencyAndStartsNextAfterCompletion() async throws {
        let first = try url("first")
        let second = try url("second")
        let third = try url("third")
        let initial = expectation(description: "First two downloads")
        initial.expectedFulfillmentCount = 2
        let next = expectation(description: "Queued download")
        let gate = PrefetchDownloadGate(onStart: { url in
            if url == third { next.fulfill() } else { initial.fulfill() }
        })
        let queue = ImagePrefetcher(maximumConcurrentDownloads: 2) { try await gate.load($0) }
        let owner = UUID()
        await queue.update([first, second, third], for: owner)
        await fulfillment(of: [initial], timeout: 2)
        let before = await gate.snapshot()
        XCTAssertEqual(Set(before.started), [first, second])
        await gate.complete(first)
        await fulfillment(of: [next], timeout: 2)
        let after = await gate.snapshot()
        XCTAssertEqual(Set(after.started), [first, second, third])
        XCTAssertEqual(after.peak, 2)
        await queue.cancel(owner: owner)
        await gate.completeAll()
    }

    func testDuplicateURLsAndOwnersShareOneDownload() async throws {
        let image = try url("shared")
        let started = expectation(description: "Shared download")
        let gate = PrefetchDownloadGate(onStart: { _ in started.fulfill() })
        let queue = ImagePrefetcher { try await gate.load($0) }
        let firstOwner = UUID()
        let secondOwner = UUID()
        await queue.update([image, image], for: firstOwner)
        await queue.update([image], for: secondOwner)
        await fulfillment(of: [started], timeout: 2)
        await queue.cancel(owner: firstOwner)
        let snapshot = await gate.snapshot()
        XCTAssertEqual(snapshot.started, [image])
        XCTAssertTrue(snapshot.cancelled.isEmpty)
        await queue.cancel(owner: secondOwner)
        await gate.completeAll()
    }

    func testCancellingOwnerRemovesQueuedWorkAndCancelsActiveDownload() async throws {
        let first = try url("active")
        let second = try url("queued")
        let started = expectation(description: "Active download")
        let stopped = expectation(description: "Cancelled active download")
        let gate = PrefetchDownloadGate(onStart: { _ in started.fulfill() }, onCancel: { _ in stopped.fulfill() })
        let queue = ImagePrefetcher(maximumConcurrentDownloads: 1) { try await gate.load($0) }
        let owner = UUID()
        await queue.update([first, second], for: owner)
        await fulfillment(of: [started], timeout: 2)
        await queue.cancel(owner: owner)
        await fulfillment(of: [stopped], timeout: 2)
        let snapshot = await gate.snapshot()
        XCTAssertEqual(snapshot.started, [first])
        XCTAssertEqual(snapshot.cancelled, [first])
        await gate.completeAll()
    }

    func testRemovingQueuedURLKeepsNeededActiveDownload() async throws {
        let first = try url("keep")
        let second = try url("remove")
        let started = expectation(description: "Needed download")
        let unwanted = expectation(description: "Removed URL must not start")
        unwanted.isInverted = true
        let gate = PrefetchDownloadGate(onStart: { url in
            if url == first { started.fulfill() } else { unwanted.fulfill() }
        })
        let queue = ImagePrefetcher(maximumConcurrentDownloads: 1) { try await gate.load($0) }
        let owner = UUID()
        await queue.update([first, second], for: owner)
        await fulfillment(of: [started], timeout: 2)
        await queue.update([first], for: owner)
        await gate.complete(first)
        await fulfillment(of: [unwanted], timeout: 0.1)
        let snapshot = await gate.snapshot()
        XCTAssertTrue(snapshot.cancelled.isEmpty)
        await queue.cancel(owner: owner)
    }

    func testFailedDownloadDoesNotBlockQueueOrRetryForever() async throws {
        let bad = try url("bad")
        let good = try url("good")
        let started = expectation(description: "Next download after failure")
        let recorder = PrefetchAttemptRecorder()
        let queue = ImagePrefetcher(maximumConcurrentDownloads: 1) { url in
            await recorder.record(url)
            if url == bad { throw URLError(.notConnectedToInternet) }
            started.fulfill()
        }
        let owner = UUID()
        await queue.update([bad, good], for: owner)
        await fulfillment(of: [started], timeout: 2)
        await queue.update([bad, good], for: owner)
        let attempts = await recorder.urls
        XCTAssertEqual(attempts, [bad, good])
        await queue.cancel(owner: owner)
    }

    func testCancelledStaleUpdateCannotReplaceCurrentDemand() async throws {
        let current = try url("current")
        let stale = try url("stale")
        let started = expectation(description: "Current download")
        let unwanted = expectation(description: "Stale update must not start")
        unwanted.isInverted = true
        let gate = PrefetchDownloadGate(onStart: { url in
            if url == current { started.fulfill() } else { unwanted.fulfill() }
        })
        let queue = ImagePrefetcher { try await gate.load($0) }
        let owner = UUID()
        await queue.update([current], for: owner)
        await fulfillment(of: [started], timeout: 2)
        let staleUpdate = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            await queue.update([stale], for: owner)
        }
        await staleUpdate.value
        await fulfillment(of: [unwanted], timeout: 0.1)
        let snapshot = await gate.snapshot()
        XCTAssertTrue(snapshot.cancelled.isEmpty)
        await queue.cancel(owner: owner)
        await gate.completeAll()
    }

    func testZeroConcurrencyLimitStillMakesProgress() async throws {
        let completed = expectation(description: "Clamped concurrency")
        let queue = ImagePrefetcher(maximumConcurrentDownloads: 0) { _ in completed.fulfill() }
        let owner = UUID()
        await queue.update([try url("valid")], for: owner)
        await fulfillment(of: [completed], timeout: 2)
        await queue.cancel(owner: owner)
    }
}

private actor PrefetchAttemptRecorder {
    private(set) var urls: [URL] = []
    func record(_ url: URL) { urls.append(url) }
}

private actor PrefetchDownloadGate {
    struct Snapshot: Sendable {
        let started: [URL]
        let cancelled: [URL]
        let peak: Int
    }

    private let onStart: @Sendable (URL) -> Void
    private let onCancel: @Sendable (URL) -> Void
    private var pending: [URL: CheckedContinuation<Void, any Error>] = [:]
    private var started: [URL] = []
    private var cancelled: [URL] = []
    private var peak = 0

    init(onStart: @escaping @Sendable (URL) -> Void, onCancel: @escaping @Sendable (URL) -> Void = { _ in }) {
        self.onStart = onStart
        self.onCancel = onCancel
    }

    func load(_ url: URL) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                pending[url] = continuation
                started.append(url)
                peak = max(peak, pending.count)
                onStart(url)
            }
        } onCancel: {
            Task { await self.cancel(url) }
        }
    }

    func complete(_ url: URL) {
        pending.removeValue(forKey: url)?.resume()
    }

    func completeAll() {
        let values = Array(pending.values)
        pending.removeAll()
        for value in values { value.resume() }
    }

    private func cancel(_ url: URL) {
        guard let continuation = pending.removeValue(forKey: url) else { return }
        cancelled.append(url)
        continuation.resume(throwing: CancellationError())
        onCancel(url)
    }

    func snapshot() -> Snapshot {
        Snapshot(started: started, cancelled: cancelled, peak: peak)
    }
}
