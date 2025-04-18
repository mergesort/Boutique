public extension StoredValue where Item == Bool {
    /// A function to toggle an @``StoredValue`` that represent a `Bool`.
    ///
    /// This is meant to provide a simple ergonomic improvement, avoiding callsites like this.
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

public extension SecurelyStoredValue where Item == Bool {
    /// A function to toggle a @``SecurelyStoredValue`` that represent a `Bool`.
    ///
    /// This is meant to provide a simple ergonomic improvement, avoiding callsites like this.
    /// ```
    /// try self.appState.$isLoggedIn.set(!self.appState.proFeaturesEnabled)
    /// ```
    ///
    /// Instead having a much simpler simpler option.
    /// ```
    /// try self.appState.$isLoggedIn.toggle()
    /// ```
    func toggle() throws {
        if let wrappedValue {
            try self.set(!wrappedValue)
        } else {
            throw KeychainError.couldNotAccessKeychain
        }
    }
}

