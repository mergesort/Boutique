import Boutique

extension Store where Item == RichNote {
    static let notesStore = Store<RichNote>(
        storage: SQLiteStorageEngine.default(appendingPath: "Notes"),
        cacheIdentifier: \.id
    )
}
