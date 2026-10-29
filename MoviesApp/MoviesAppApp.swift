import SwiftUI
import MovieCore

@main
struct MoviesAppApp: App {
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            TrendingView(
                viewModel: dependencies.trending,
                movieDetailsProvider: dependencies.details,
                searchViewModel: dependencies.search
            )
            .environment(dependencies.favorites)
            .task { await dependencies.favorites.load() }
            .alert("Favorites", isPresented: Binding(
                get: { dependencies.favorites.errorMessage != nil },
                set: { if !$0 { dependencies.favorites.errorMessage = nil } }
            )) {
                Button("OK") { dependencies.favorites.errorMessage = nil }
            } message: {
                Text(dependencies.favorites.errorMessage ?? "")
            }
        }
    }
}
