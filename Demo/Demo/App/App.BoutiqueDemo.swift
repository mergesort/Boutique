import SwiftUI

@main
struct BoutiqueDemoApp: App {

    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .task({
                    do {
                        print("App last opened:", appState.lastAppLaunchTimestamp ?? "Never")

                        // Saving the last time the app was opened to demonstrate how @StoredValue
                        // persists values. The next time you open the app it should print
                        //  the timestamp the app was last lauched, no databases needed.
                        let currentTime = Date.now
                        try await appState.$lastAppLaunchTimestamp.set(currentTime)
                        print("Current time is \(currentTime). You will see that timestamp next app launch.")
                    } catch {
                        print("Couldn't set app launch timestamp", error)
                    }
                })
        }
    }
}
