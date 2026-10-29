//
//  ImageDataLoaderTests.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import Foundation
import XCTest
@testable import MovieCore

final class ImageDataLoaderTests: XCTestCase {
    private func session(_ protocolClass: AnyClass = ImageURLProtocol.self) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [protocolClass]
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }

    func testDownloadedImageSurvivesNewLoaderWithoutNetwork() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let online = session()
        let offline = session(ImageOfflineURLProtocol.self)
        defer { online.invalidateAndCancel(); offline.invalidateAndCancel() }
        let url = try XCTUnwrap(URL(string: "https://images.example.test/valid.png"))
        let first = try await ImageDataLoader(cache: DiskDataStore(directory: root), session: online).data(for: url)
        let saved = try await ImageDataLoader(cache: DiskDataStore(directory: root), session: offline).data(for: url)
        XCTAssertEqual(saved, first)
        XCTAssertFalse(saved.isEmpty)
    }

    func testHTTPErrorAndInvalidImageAreNotPersisted() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = session()
        defer { session.invalidateAndCancel() }
        let cache = DiskDataStore(directory: root)
        let loader = ImageDataLoader(cache: cache, session: session)
        for path in ["missing", "invalid"] {
            let url = try XCTUnwrap(URL(string: "https://images.example.test/\(path)"))
            do {
                _ = try await loader.data(for: url)
                XCTFail("Expected a rejected image response.")
            } catch let error as URLError {
                XCTAssertEqual(error.code, .badServerResponse)
            }
            let saved = try await cache.read(key: url.absoluteString)
            XCTAssertNil(saved)
        }
    }

    func testCorruptSavedImageIsReplacedFromNetwork() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = session()
        defer { session.invalidateAndCancel() }
        let cache = DiskDataStore(directory: root)
        let url = try XCTUnwrap(URL(string: "https://images.example.test/valid.png"))
        try await cache.write(Data("not an image".utf8), key: url.absoluteString)
        let downloaded = try await ImageDataLoader(cache: cache, session: session).data(for: url)
        XCTAssertEqual(downloaded, ImageURLProtocol.image)
        let saved = try await cache.read(key: url.absoluteString)
        XCTAssertEqual(saved, downloaded)
    }

    func testConcurrentRequestsReturnSameImage() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = session()
        defer { session.invalidateAndCancel() }
        let loader = ImageDataLoader(cache: DiskDataStore(directory: root), session: session)
        let url = try XCTUnwrap(URL(string: "https://images.example.test/valid.png"))
        let values = try await withThrowingTaskGroup(of: Data.self, returning: [Data].self) { group in
            for _ in 0..<10 { group.addTask { try await loader.data(for: url) } }
            var values: [Data] = []
            for try await value in group { values.append(value) }
            return values
        }
        XCTAssertEqual(values.count, 10)
        XCTAssertTrue(values.allSatisfy { $0 == ImageURLProtocol.image })
    }

    func testCancelledCallerDoesNotReturnCachedImage() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = DiskDataStore(directory: root)
        let url = try XCTUnwrap(URL(string: "https://images.example.test/valid.png"))
        try await cache.write(ImageURLProtocol.image, key: url.absoluteString)
        let loader = ImageDataLoader(cache: cache)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await loader.data(for: url)
        }
        do {
            _ = try await task.value
            XCTFail("Expected cancellation.")
        } catch is CancellationError {
            // Cancellation takes precedence over a cache hit.
        }
    }
}

private final class ImageURLProtocol: URLProtocol, @unchecked Sendable {
    static let image = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a6l8AAAAASUVORK5CYII="
    ) ?? Data()

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url, statusCode: url.lastPathComponent == "missing" ? 404 : 200,
                httpVersion: nil, headerFields: ["Content-Type": "image/png"]
              ) else { return }
        let data = url.lastPathComponent == "invalid" ? Data("invalid".utf8) : Self.image
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class ImageOfflineURLProtocol: URLProtocol, @unchecked Sendable {
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        XCTFail("A valid disk image must be returned without a network request.")
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() {}
}
