# MoviesApp

An iOS technical assignment built with SwiftUI, UIKit, and the TMDB API.

## Features

- Trending movies in an adaptive UICollectionView compositional layout.
- Infinite scrolling with pagination error handling and retry.
- Movie and TV series search with a 500 ms throttle.
- Cancellation and protection against outdated search responses.
- Movie and series details with ratings, votes, dates, and duration.
- Season and episode counts for series.
- Image resolution selected using the displayed width and screen scale.
- In-memory image caching with NSCache.
- Adaptive layouts for iPhone and iPad in portrait and landscape.

## Requirements

- Xcode 26.x.
- iOS 17.6 or later.
- A TMDB API Read Access Token for live API requests.

Dependencies are managed through Swift Package Manager.
Networking uses native URLSession.

## Run the app

1. Open MoviesApp.xcodeproj.
2. Allow Swift Package Manager to resolve dependencies.
3. Duplicate the MoviesApp-Dev scheme and name it MoviesApp-Local.
4. Keep the local scheme unshared.
5. Open Edit Scheme → Run → Arguments.
6. Add an enabled environment variable:
   - Name: TMDB_READ_ACCESS_TOKEN
   - Value: your TMDB API Read Access Token.
7. Select an iPhone or iPad simulator and run the local scheme.

The token is passed through the launch environment.
Personal schemes are stored in xcuserdata, which is ignored by Git.

Approve the SwiftLint build plugin if Xcode requests it.

## Schemes

| Scheme | Purpose |
|---|---|
| MoviesApp-Dev | Development builds and tests using Dev configuration |
| MoviesApp-Prod | Run, Profile, and Archive using Prod configuration |
| MoviesApp-Local | Personal development scheme with the API token |

MoviesApp-Prod uses Dev configuration for tests because UI-test fixtures
are compiled under DEBUG.

## Architecture

The app uses MVVM with dependency injection.

- MovieCore contains public domain models, provider protocols,
  API response DTOs, image URL sizing, and the TMDB client.
- MoviesApp contains SwiftUI screens, observable view models,
  image caching, and the UIKit collection view integration.
- View models are MainActor-isolated and use Observation.
- Provider protocols and domain models conform to Sendable.
- The project uses Swift 6 language mode.
- Movie and series results retain their media type for details navigation.

## Tests

Select MoviesApp-Dev and press Command-U to run the shared test plan.

The test plan includes:

- MovieCoreTests: decoding, mapping, request construction,
  image URL sizing, validation, and API error handling.
- MoviesAppTests: view model states, pagination, retry,
  throttling, cancellation, and outdated responses.
- MoviesAppUITests: navigation, movie and series search,
  and empty search results.

Tests use URLProtocol stubs and deterministic providers.
UI tests launch the app with the -ui-testing argument.
No real API token is required for tests.

Latest recorded full test run:

- 51 tests passed.
- MovieCore.framework line coverage: 97.4%.
- Destination: iPhone 17 Pro simulator, iOS 26.5.
- Scheme: MoviesApp-Dev.

## SwiftLint

SwiftLint runs through an SPM build tool plugin.
Project rules are configured in .swiftlint.yml.

## Scope and limitations

- Search currently displays the first page of results.
- Decoded images are cached in memory.
- Favorites, dedicated offline mode, image prefetching,
  progressive image loading, and XCFramework packaging are not implemented.
