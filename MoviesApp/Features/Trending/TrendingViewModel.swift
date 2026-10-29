import Foundation
import Observation
import MovieCore

@MainActor
@Observable
final class TrendingViewModel {
    enum State {
        case idle
        case loading
        case loaded([Movie])
        case failed(String)
    }

    enum NextPageState {
        case idle
        case loading
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var isShowingSavedData = false
    private(set) var nextPageState: NextPageState = .idle

    private let moviesProvider: any TrendingMoviesProviding

    private var currentPage = 0
    private var totalPages = 0
    private var reachedEnd = false

    init(moviesProvider: any TrendingMoviesProviding) {
        self.moviesProvider = moviesProvider
    }

    /// Loads the first page unless content is already loaded or loading.
    func load() async {
        switch state {
        case .loading, .loaded:
            return
        case .idle, .failed:
            break
        }

        guard !Task.isCancelled else {
            return
        }

        isShowingSavedData = false
        state = .loading

        do {
            let result = try await moviesProvider.fetchTrendingMovies(page: 1)

            try Task.checkCancellation()

            guard result.page == 1 else {
                throw PaginationError.unexpectedPage
            }

            currentPage = result.page
            totalPages = result.totalPages
            reachedEnd = result.movies.isEmpty

            isShowingSavedData = result.isFromCache
            state = .loaded(uniqueMovies(result.movies))
        } catch {
            if Task.isCancelled || error is CancellationError {
                state = .idle
                return
            }

            state = .failed(
                "Unable to load movies. Please try again."
            )
        }
    }

    /// Appends the next page while keeping existing movies visible.
    func loadNextPage() async {
        guard case .loaded(let movies) = state,
              case .idle = nextPageState,
              currentPage < totalPages,
              !reachedEnd,
              !Task.isCancelled else {
            return
        }

        let requestedPage = currentPage + 1
        nextPageState = .loading

        defer {
            if case .loading = nextPageState {
                nextPageState = .idle
            }
        }

        do {
            let result = try await moviesProvider.fetchTrendingMovies(
                page: requestedPage
            )

            try Task.checkCancellation()

            guard result.page == requestedPage else {
                throw PaginationError.unexpectedPage
            }

            let updatedMovies = uniqueMovies(movies + result.movies)

            currentPage = result.page
            totalPages = result.totalPages
            reachedEnd = updatedMovies.count == movies.count

            isShowingSavedData = isShowingSavedData || result.isFromCache
            state = .loaded(updatedMovies)
        } catch {
            guard !Task.isCancelled,
                  !(error is CancellationError) else {
                return
            }

            nextPageState = .failed(
                "Unable to load more movies. Please try again."
            )
        }
    }

    /// Retries the same page after a pagination error.
    func retryNextPage() async {
        guard case .failed = nextPageState else {
            return
        }

        nextPageState = .idle
        await loadNextPage()
    }

    /// Removes duplicate IDs while preserving the original order.
    private func uniqueMovies(_ movies: [Movie]) -> [Movie] {
        var seenIDs = Set<Int>()

        return movies.filter {
            seenIDs.insert($0.id).inserted
        }
    }

    private enum PaginationError: Error {
        case unexpectedPage
    }
}
