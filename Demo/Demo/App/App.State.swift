import Boutique
import Foundation

@Observable
final class AppState {
    @ObservationIgnored
    @StoredValue(key: "funkyRedPandaModeEnabled")
    var funkyRedPandaModeEnabled = false

    @ObservationIgnored
    @StoredValue(key: "fetchedRedPandas")
    var fetchedRedPandas: [URL] = []

    @ObservationIgnored
    @StoredValue<Date?>(key: "lastAppLaunchTimestamp")
    var lastAppLaunchTimestamp = nil
}
