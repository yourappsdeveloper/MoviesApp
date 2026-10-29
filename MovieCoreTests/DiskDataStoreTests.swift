//
//  DiskDataStoreTests.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import Foundation
import XCTest
@testable import MovieCore

final class DiskDataStoreTests: XCTestCase {
    func testDataSurvivesStoreRecreationAndKeysCannotEscapeDirectory() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DiskDataStore(directory: root)
        let key = "../../outside?query=a/b"
        try await store.write(Data([1, 2, 3]), key: key)
        let restored = try await DiskDataStore(directory: root).read(key: key)
        XCTAssertEqual(restored, Data([1, 2, 3]))
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files.first?.lastPathComponent.count, 64)
    }

    func testMissingDataAndRemoveAll() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DiskDataStore(directory: root)
        let missing = try await store.read(key: "missing")
        XCTAssertNil(missing)
        try await store.write(Data([1]), key: "key")
        try await store.write(Data([2]), key: "other")
        try await store.remove(key: "key")
        let kept = try await store.read(key: "other")
        XCTAssertEqual(kept, Data([2]))
        try await store.removeAll()
        try await store.removeAll()
        let removed = try await store.read(key: "key")
        XCTAssertNil(removed)
    }

    func testCacheRemainsWithinByteLimit() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DiskDataStore(directory: root, byteLimit: 6)
        try await store.write(Data(repeating: 1, count: 4), key: "first")
        try await store.write(Data(repeating: 2, count: 4), key: "second")
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        let size = try files.reduce(0) { try $0 + Data(contentsOf: $1).count }
        XCTAssertLessThanOrEqual(size, 6)
        let newest = try await store.read(key: "second")
        XCTAssertEqual(newest, Data(repeating: 2, count: 4))
    }

    func testOversizedItemIsNotStored() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DiskDataStore(directory: root, byteLimit: 2)
        try await store.write(Data([1, 2, 3]), key: "large")
        let value = try await store.read(key: "large")
        XCTAssertNil(value)
    }
}
