import Boutique
import Foundation

final class AppState: ObservableObject {
    @StoredValue(key: "funkyRedPandaModeEnabled")
    var funkyRedPandaModeEnabled = false

    @StoredValue<Date?>(key: "lastAppLaunchTimestamp")
    var lastAppLaunchTimestamp = nil
}
