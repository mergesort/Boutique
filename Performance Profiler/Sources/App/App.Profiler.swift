import SwiftUI

@main
struct ProfilerApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// A wrapper around each ContentView so we can access the Environment which is unavailable at the `App` level
private struct ContentView: View {

    @Environment(\.isRegularSizeClass) private var isRegularSizeClass

    var body: some View {
        if self.isRegularSizeClass {
            // All iPads
            RegularContentView()
        } else {
            // All iPhones including Plus/Max sized devices
            CompactContentView()
        }
    }

}
