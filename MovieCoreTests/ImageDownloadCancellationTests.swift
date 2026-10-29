//
//  ImageDownloadCancellationTests.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import Foundation
import XCTest
@testable import MovieCore

final class ImageDownloadCancellationTests: XCTestCase {
    func testTwoConsumersUseOneTransportRequest() async throws {
        let fixture = try DownloadFixture()
        defer { fixture.cleanUp() }
        let first = Task { try await fixture.loader.data(for: fixture.url) }
        let second = Task { try await fixture.loader.data(for: fixture.url) }
        await fulfillment(of: [fixture.control.started], timeout: 2)
        guard await waitForConsumers(2, fixture: fixture) else {
            first.cancel()
            second.cancel()
            return
        }
        fixture.control.respond()
        let firstData = try await first.value
        let secondData = try await second.value
        XCTAssertEqual(firstData, ControlledImageTransfer.image)
        XCTAssertEqual(secondData, firstData)
        XCTAssertEqual(fixture.control.requestCount, 1)
    }

    func testCancellingPrefetchConsumerKeepsVisibleConsumerAlive() async throws {
        let fixture = try DownloadFixture()
        defer { fixture.cleanUp() }
        let cancelled = expectation(description: "Prefetch consumer cancelled")
        let prefetch = Task {
            defer { cancelled.fulfill() }
            do {
                _ = try await fixture.loader.data(for: fixture.url)
                XCTFail("Expected the cancelled consumer to stop waiting.")
            } catch is CancellationError {
                // The visible consumer still owns the underlying request.
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
        await fulfillment(of: [fixture.control.started], timeout: 2)
        let visible = Task { try await fixture.loader.data(for: fixture.url) }
        guard await waitForConsumers(2, fixture: fixture) else {
            prefetch.cancel()
            visible.cancel()
            return
        }
        prefetch.cancel()
        await fulfillment(of: [cancelled], timeout: 2)
        XCTAssertEqual(fixture.control.stopCount, 0)
        fixture.control.respond()
        let data = try await visible.value
        XCTAssertEqual(data, ControlledImageTransfer.image)
        XCTAssertEqual(fixture.control.requestCount, 1)
    }

    func testCancellingLastConsumerCancelsTransport() async throws {
        let fixture = try DownloadFixture()
        defer { fixture.cleanUp() }
        let cancelled = expectation(description: "Last consumer cancelled")
        let request = Task {
            defer { cancelled.fulfill() }
            do {
                _ = try await fixture.loader.data(for: fixture.url)
                XCTFail("Expected cancellation.")
            } catch is CancellationError {
                // The consumer stops waiting without needing a server response.
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
        await fulfillment(of: [fixture.control.started], timeout: 2)
        request.cancel()
        await fulfillment(of: [cancelled, fixture.control.stopped], timeout: 2)
        XCTAssertEqual(fixture.control.stopCount, 1)
        let remaining = await fixture.loader.pendingConsumerCount(for: fixture.url)
        XCTAssertEqual(remaining, 0)
    }

    private func waitForConsumers(_ count: Int, fixture: DownloadFixture) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        while clock.now < deadline {
            if await fixture.loader.pendingConsumerCount(for: fixture.url) == count { return true }
            await Task.yield()
        }
        XCTFail("Expected both consumers to register before continuing.")
        return false
    }
}

private struct DownloadFixture: Sendable {
    let root: URL
    let url: URL
    let control: ControlledImageTransfer
    let session: URLSession
    let loader: ImageDataLoader

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        url = try XCTUnwrap(URL(string: "https://images.example.test/\(UUID().uuidString).png"))
        control = ControlledImageTransfer()
        ImageTransferRegistry.shared.register(control, for: url)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ControlledImageURLProtocol.self]
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
        loader = ImageDataLoader(cache: DiskDataStore(directory: root), session: session)
    }

    func cleanUp() {
        session.invalidateAndCancel()
        ImageTransferRegistry.shared.remove(url)
        try? FileManager.default.removeItem(at: root)
    }
}

private final class ImageTransferRegistry: @unchecked Sendable {
    static let shared = ImageTransferRegistry()
    private let lock = NSLock()
    private var transfers: [URL: ControlledImageTransfer] = [:]

    func register(_ transfer: ControlledImageTransfer, for url: URL) {
        lock.withLock { transfers[url] = transfer }
    }

    func transfer(for url: URL) -> ControlledImageTransfer? {
        lock.withLock { transfers[url] }
    }

    func remove(_ url: URL) {
        _ = lock.withLock { transfers.removeValue(forKey: url) }
    }
}

private final class ControlledImageTransfer: @unchecked Sendable {
    static let image = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a6l8AAAAASUVORK5CYII="
    ) ?? Data()
    let started = XCTestExpectation(description: "Image transport started")
    let stopped = XCTestExpectation(description: "Image transport cancelled")
    private let lock = NSLock()
    private var protocols: [ObjectIdentifier: URLProtocol] = [:]
    private var starts = 0
    private var stops = 0

    var requestCount: Int { lock.withLock { starts } }
    var stopCount: Int { lock.withLock { stops } }

    func start(_ request: URLProtocol) {
        lock.withLock {
            starts += 1
            protocols[ObjectIdentifier(request)] = request
        }
        started.fulfill()
    }

    func stop(_ request: URLProtocol) {
        let removed = lock.withLock {
            guard protocols.removeValue(forKey: ObjectIdentifier(request)) != nil else { return false }
            stops += 1
            return true
        }
        if removed { stopped.fulfill() }
    }

    func respond() {
        let requests = lock.withLock {
            let values = Array(protocols.values)
            protocols.removeAll()
            return values
        }
        for request in requests {
            guard let url = request.request.url,
                  let response = HTTPURLResponse(
                    url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "image/png"]
                  ) else { continue }
            request.client?.urlProtocol(request, didReceive: response, cacheStoragePolicy: .notAllowed)
            request.client?.urlProtocol(request, didLoad: Self.image)
            request.client?.urlProtocolDidFinishLoading(request)
        }
    }
}

private final class ControlledImageURLProtocol: URLProtocol, @unchecked Sendable {
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let transfer = ImageTransferRegistry.shared.transfer(for: url) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        transfer.start(self)
    }

    override func stopLoading() {
        guard let url = request.url else { return }
        ImageTransferRegistry.shared.transfer(for: url)?.stop(self)
    }
}
