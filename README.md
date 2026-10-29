# MoviesApp

An iOS technical assignment built with Swift 6, SwiftUI, UIKit, and the
[TMDB API](https://developer.themoviedb.org/docs/getting-started).

## Features

- Trending movies displayed in an adaptive `UICollectionView` compositional layout.
- Infinite scrolling with duplicate filtering, pagination errors, and retry.
- Movie and TV series search with content-type selection and a 500 ms throttle.
- Search cancellation and protection against outdated responses.
- Movie and series details with ratings, votes, dates, and duration; series also
  show season and episode counts.
- Persistent favorites with indicators on cards and details, plus a dedicated list.
- Offline fallback for previously loaded lists, searches, and details.
- Poster and backdrop resolution selected from the displayed width and screen scale.
- Memory and disk image caching, with upcoming poster pre-caching.
- Adaptive iPhone and iPad layouts in portrait and landscape, including larger text sizes.

## Requirements

- Xcode 26.x.
- iOS / iPadOS 17.6 or later.
- A TMDB API Read Access Token for live requests.

Dependencies are resolved through Swift Package Manager. Networking uses native
`URLSession`; SwiftLint runs through an SPM build tool plugin.

## Run locally

1. Open `MoviesApp.xcodeproj` and allow package resolution to finish.
2. In **Product > Scheme > Manage Schemes**, duplicate `MoviesApp-Dev` and name it
   `MoviesApp-Local`.
3. Keep the local scheme **unshared**.
4. Open **Edit Scheme > Run > Arguments**.
5. Add an enabled environment variable named `TMDB_READ_ACCESS_TOKEN` with your
   TMDB API Read Access Token as its value.
6. Select an iPhone or iPad simulator and run `MoviesApp-Local`.
7. Approve the SwiftLint build plugin if Xcode requests it.

The token is read from the launch environment. Keep personal tokens in the local,
unshared scheme; do not add them to source files or shared schemes. Personal
scheme settings under `xcuserdata` are ignored by Git.

Without a token, the app can read saved API responses and favorites. A fresh
installation needs a token and connectivity to obtain content. To test an offline
launch outside Xcode, first populate the cache in a session with a token.

## Schemes and configurations

| Scheme | Purpose |
| --- | --- |
| `MoviesApp-Dev` | Development builds and the shared test plan using `Dev` configuration. |
| `MoviesApp-Prod` | Production run, profile, analyze, and archive using `Prod` configuration. |
| `MoviesApp-Local` | Personal, unshared development scheme containing the API token. |

The production scheme uses `Dev` configuration for its test action because
UI-test fixtures are compiled under `DEBUG`.

## Architecture

The project uses MVVM with dependency injection and Swift 6 concurrency.

| Area | Responsibility |
| --- | --- |
| `MovieCore` | Domain models, provider protocols, TMDB networking and DTO mapping, persistent storage, image loading, and the prefetch queue. |
| `MoviesApp` | SwiftUI screens, observable view models, dependency composition, UIKit collection integration, and prepared-image memory caching. |
| Test targets | Framework tests, view-model and UIKit integration tests, and UI navigation/persistence tests. |

View models are `@MainActor`-isolated and use Observation. Provider protocols and
domain models are `Sendable`. `AppDependencies` composes the providers and the
shared favorites view model.

`OfflineMoviesProvider` decorates the existing provider contracts with persistent
response caching. `FavoritesRepository`, `DiskDataStore`, `ImageDataLoader`, and
`ImagePrefetcher` use actors to coordinate mutable state and asynchronous work.

Movie and series identities include their media type where their TMDB ID can
overlap, including favorites, details requests, and persistent cache keys.

## Favorites and offline behavior

Favorites are stored separately from disposable caches in an atomic JSON file
under Application Support. Adding or removing an item updates the shared list and
its heart indicators after a successful write. Failed reads or writes are
reported; corrupt favorites data is not silently overwritten.

API requests try the network first. Connectivity failures can return the saved
response for the exact page, query, ID, and media type. The screen identifies saved
API content because it may be out of date. HTTP errors, decoding errors, and
cancellation are not hidden by a cached response.

A later request tries the network again when a token is available. Already
visible saved content stays on screen until a new request is made, for example
by reopening details, repeating a search, or relaunching the app.

Favorites retain card metadata. Full details and image sizes are available
offline only when previously loaded and still cached. Favoriting an item does
not download all of its details or images. Cache eviction never removes favorites.

## Image caching and pre-caching

- Prepared images use a shared `NSCache`, configured with a 64 MiB cost limit
  and a 100-image count limit.
- Encoded image storage is limited to 100 MiB; API response storage is limited
  to 20 MiB. Old entries are evicted as new entries are written.
- UIKit prefetch callbacks request upcoming posters in Trending, Search, and
  Favorites through one shared queue with up to three concurrent operations.
- Image URLs use cell width and display scale. Obsolete prefetch demand is
  released when UIKit cancels it, data is replaced, a collection is removed, or
  a changed layout is observed.
- URLs are deduplicated across collections, with separate ownership per collection.
  Prefetch and visible cards share downloads, disk storage, and prepared images.
- Cancelling one image consumer leaves a request needed by another consumer
  alive. The transport is cancelled after its final consumer leaves.
- Prefetch failures stay silent and do not retry indefinitely. Cells that were
  not prefetched load normally; foreground requests do not wait in the prefetch queue.

The concurrency limit applies to speculative prefetch work. Pre-caching warms
posters for already loaded list content; it does not fetch extra API pages,
searches, or full details.

## Tests

Select **MoviesApp-Dev**, choose an iPhone or iPad simulator, and press
**Command-U** to run `MoviesAppTests.xctestplan`.

| Target | Coverage |
| --- | --- |
| `MovieCoreTests` | DTO mapping, request construction, validation, API errors, image sizing, favorites persistence, cache limits, offline fallback, prefetch scheduling, shared downloads, and cancellation. |
| `MoviesAppTests` | Loading states, pagination, retry, search throttling/cancellation, stale responses, favorites errors, saved-content indicators, UIKit prefetch callbacks, and layout-dependent image requests. |
| `MoviesAppUITests` | Movie and series navigation/search, empty states, favorites persistence and removal, and cached content after an offline relaunch. |

Tests use `URLProtocol` stubs, deterministic providers, and controlled asynchronous
responses. A real API token is not required. Coverage collection targets
`MovieCore`; inspect the latest test report in Report Navigator to confirm the
assignment's minimum 80% framework coverage.

UI-test launch arguments:

| Argument | Purpose |
| --- | --- |
| `-ui-testing` | Uses deterministic fixtures and isolated temporary storage. |
| `-ui-test-storage <UUID>` | Reuses one isolated store across relaunches within a persistence test. |
| `-ui-testing-offline` | Makes the fixture provider return a connectivity error to exercise disk fallback. |

These arguments are for tests and do not belong in the normal development scheme.
Test results and coverage should be taken from the latest full run of the current
revision, rather than from an earlier feature branch.

## SwiftLint

SwiftLint runs during builds through the SPM build tool plugin. Project rules
are configured in `.swiftlint.yml`, including line/function length thresholds
and the opt-in `empty_count` and `empty_string` rules.

## Validation before delivery

1. Run the complete `MoviesApp-Dev` test plan and review framework coverage.
2. Build `MoviesApp-Prod` to verify the production configuration.
3. Check iPhone and iPad layouts in both orientations, including larger text sizes.
4. With a live token, load lists, searches, details, and images; save favorites,
   terminate, disable connectivity, and relaunch to check cached behavior.
5. Scroll quickly, reverse direction, rotate, and dismiss sheets during image
   loading to check prefetch cancellation and normal image loading.
6. Run `git diff --check` and commit the final source and documentation changes.

## Current limitations and remaining bonuses

- Search displays the first page of results.
- Offline mode cannot retrieve uncached content or image sizes that were never loaded.
- Saved API content is refreshed by a new request, rather than automatically
  when connectivity returns.
- Low-resolution previews followed by final images are not implemented.
- Multi-platform `MovieCore.xcframework` packaging is not implemented.
