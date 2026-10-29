//
//  DiskDataStore.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import CryptoKit
import Foundation

/// Serializes file access and bounds disposable offline cache storage.
public actor DiskDataStore {
    private let directory: URL
    private let byteLimit: Int

    public init(directory: URL, byteLimit: Int = 100 * 1024 * 1024) {
        self.directory = directory
        self.byteLimit = byteLimit
    }

    public func read(key: String) throws -> Data? {
        let url = fileURL(key)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    public func write(_ data: Data, key: String) throws {
        guard data.count <= byteLimit else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = fileURL(key)
        try data.write(to: url, options: .atomic)
        try trim(keeping: url)
    }

    public func remove(key: String) throws {
        let url = fileURL(key)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    public func removeAll() throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.removeItem(at: directory)
    }

    private func fileURL(_ key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(digest)
    }

    private func trim(keeping newest: URL) throws {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        let files = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: Array(keys)
        ).map { url in
            (url, try url.resourceValues(forKeys: keys))
        }.sorted {
            ($0.1.contentModificationDate ?? .distantPast) < ($1.1.contentModificationDate ?? .distantPast)
        }
        var total = files.reduce(0) { $0 + ($1.1.fileSize ?? 0) }
        for (url, values) in files where total > byteLimit && url != newest {
            try FileManager.default.removeItem(at: url)
            total -= values.fileSize ?? 0
        }
    }
}
