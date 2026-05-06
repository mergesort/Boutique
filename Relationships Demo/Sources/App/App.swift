import SwiftUI

@main
struct RelationshipsDemoApp: App {
    var body: some Scene {
        WindowGroup {
            RelationshipDemoView()
                #if DEBUG
                .task {
                    await RelationshipsDemoController.shared.runSelfTestIfRequested()
                }
                #endif
        }
    }
}
