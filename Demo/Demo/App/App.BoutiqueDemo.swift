import SwiftUI

@main
struct BoutiqueDemoApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onAppear(perform: {
                    // Saving the last time the app was opened to demonstrate how @StoredValue
                    // persists values. The next time you open the app it should print
                    // the timestamp the app was last lauched, no databases needed.
                    print("App last opened:", appState.lastAppLaunchTimestamp ?? "Never")

                    let currentTime = Date.now
                    appState.$lastAppLaunchTimestamp.set(currentTime)
                    print("Current time is \(currentTime). You will see that timestamp next app launch.")
                })
        }
    }
}
