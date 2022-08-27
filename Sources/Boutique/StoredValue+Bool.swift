public extension StoredValue where Item == Bool {

    /// A function to toggle an @``StoredValue`` that represent a `Bool`.
    ///
    /// This is meant to provide a simple ergonomic improvement, to avoid callsites like this.
    /// ```
    /// self.appState.$proFeaturesEnabled.set(!self.appState.proFeaturesEnabled)
    /// ```
    ///
    /// Instead having a much simpler simpler option.
    /// ```
    /// self.appState.$proFeaturesEnabled.toggle()
    /// ```
    func toggle() {
        self.set(!self.wrappedValue)
    }

}

public extension AsyncStoredValue where Item == Bool {

    /// A function to toggle an @``AsyncStoredValue`` that represent a `Bool`.
    ///
    /// This is meant to provide a simple ergonomic improvement, to avoid callsites like this.
    /// ```
    /// try await self.appState.$proFeaturesEnabled.set(!self.appState.proFeaturesEnabled)
    /// ```
    ///
    /// Instead having a much simpler simpler option.
    /// ```
    /// try await self.appState.$proFeaturesEnabled.toggle()
    /// ```
    func toggle() async throws {
        try await self.set(!self.wrappedValue)
    }

}
