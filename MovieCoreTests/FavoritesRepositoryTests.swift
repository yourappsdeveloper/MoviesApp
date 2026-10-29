//
//  FavoritesRepositoryTests.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import Foundation
import XCTest
@testable import MovieCore

final class FavoritesRepositoryTests: XCTestCase {
    private func directory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    private func movie(_ type: MediaType = .movie, id: Int = 42) -> Movie {
        Movie(id: id, title: "Sample", overview: "Overview", posterPath: "/poster.jpg", mediaType: type)
    }

    func testNewRepositoryIsEmpty() async throws {
        let root = directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let values = try await FavoritesRepository(fileURL: root.appendingPathComponent("favorites.json")).load()
        XCTAssertTrue(values.isEmpty)
    }

    func testFavoritesSurviveNewRepositoryInstance() async throws {
        let root = directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("favorites.json")
        _ = try await FavoritesRepository(fileURL: file).toggle(movie())
        let restored = try await FavoritesRepository(fileURL: file).load()
        XCTAssertEqual(restored, [movie()])
    }

    func testMovieAndSeriesWithSameIDAreIndependent() async throws {
        let root = directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = FavoritesRepository(fileURL: root.appendingPathComponent("favorites.json"))
        _ = try await repository.toggle(movie())
        let both = try await repository.toggle(movie(.series))
        XCTAssertEqual(both.map(\.mediaType), [.series, .movie])
        let remaining = try await repository.toggle(movie())
        XCTAssertEqual(remaining, [movie(.series)])
    }

    func testToggleRemovesSameIdentityWithUpdatedMetadata() async throws {
        let root = directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = FavoritesRepository(fileURL: root.appendingPathComponent("favorites.json"))
        _ = try await repository.toggle(movie())
        let updated = Movie(id: 42, title: "Updated", overview: "Changed", posterPath: nil)
        let remaining = try await repository.toggle(updated)
        XCTAssertTrue(remaining.isEmpty)
        let restored = try await repository.load()
        XCTAssertTrue(restored.isEmpty)
    }

    func testConcurrentTogglesDoNotLoseDistinctFavorites() async throws {
        let root = directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = FavoritesRepository(fileURL: root.appendingPathComponent("favorites.json"))
        try await withThrowingTaskGroup(of: Void.self) { group in
            for identifier in 1...20 {
                let value = movie(id: identifier)
                group.addTask { _ = try await repository.toggle(value) }
            }
            try await group.waitForAll()
        }
        let values = try await repository.load()
        XCTAssertEqual(Set(values.map(\.id)), Set(1...20))
    }

    func testCorruptFileIsReportedAndNeverOverwritten() async throws {
        let root = directory()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("favorites.json")
        let original = Data("broken JSON".utf8)
        try original.write(to: file)
        let repository = FavoritesRepository(fileURL: file)
        do {
            _ = try await repository.toggle(movie())
            XCTFail("Expected corrupt storage to fail.")
        } catch is DecodingError {
            XCTAssertEqual(try Data(contentsOf: file), original)
        }
    }

    func testWriteFailureIsReported() async throws {
        let root = directory()
        defer { try? FileManager.default.removeItem(at: root) }
        try Data().write(to: root)
        let repository = FavoritesRepository(fileURL: root.appendingPathComponent("favorites.json"))
        do {
            _ = try await repository.toggle(movie())
            XCTFail("Expected writing beneath a file to fail.")
        } catch {
            let original = try Data(contentsOf: root)
            XCTAssertTrue(original.isEmpty)
        }
    }
}
