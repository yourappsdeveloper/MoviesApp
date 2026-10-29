//
//  ImagePrefetcher.swift
//  MoviesApp
//
//  Created by Alex  on 29.10.2026.
//

import Foundation

/// Shares a bounded queue across collection views without coupling their lifetimes.
public actor ImagePrefetcher {
    private struct Work {
        let id: UUID
        let task: Task<Void, Never>
    }

    private let maximumConcurrentDownloads: Int
    private let load: @Sendable (URL) async throws -> Void
    private var owners: [UUID: [URL]] = [:]
    private var queued: [URL] = []
    private var active: [URL: Work] = [:]
    private var completed: Set<URL> = []

    public init(
        maximumConcurrentDownloads: Int = 3,
        load: @escaping @Sendable (URL) async throws -> Void
    ) {
        self.maximumConcurrentDownloads = max(1, maximumConcurrentDownloads)
        self.load = load
    }

    /// Replaces one collection's requested URLs. Cancelled updates cannot undo newer ones.
    public func update(_ urls: [URL], for owner: UUID) {
        guard !Task.isCancelled else { return }
        replace(urls, for: owner)
    }

    public func cancel(owner: UUID) {
        replace([], for: owner)
    }

    private func replace(_ urls: [URL], for owner: UUID) {
        var seen: Set<URL> = []
        let uniqueURLs = urls.filter { seen.insert($0).inserted }
        if uniqueURLs.isEmpty {
            owners[owner] = nil
        } else {
            owners[owner] = uniqueURLs
        }
        let desired = Set(owners.values.flatMap { $0 })
        completed.formIntersection(desired)
        queued.removeAll { !desired.contains($0) }
        for (url, work) in active where !desired.contains(url) {
            work.task.cancel()
        }
        for url in uniqueURLs where active[url] == nil && !completed.contains(url) && !queued.contains(url) {
            queued.append(url)
        }
        startNext()
    }

    private func startNext() {
        while active.count < maximumConcurrentDownloads, !queued.isEmpty {
            let url = queued.removeFirst()
            let identifier = UUID()
            let task = Task(priority: .utility) { [load] in
                do {
                    try Task.checkCancellation()
                    try await load(url)
                } catch {
                    // Prefetch failures stay silent; visible cards may retry normally.
                }
                self.finished(url, identifier: identifier, cancelled: Task.isCancelled)
            }
            active[url] = Work(id: identifier, task: task)
        }
    }

    private func finished(_ url: URL, identifier: UUID, cancelled: Bool) {
        guard active[url]?.id == identifier else { return }
        active[url] = nil
        let isDesired = owners.values.contains { $0.contains(url) }
        if isDesired {
            if cancelled {
                queued.append(url)
            } else {
                completed.insert(url)
            }
        }
        startNext()
    }
}
