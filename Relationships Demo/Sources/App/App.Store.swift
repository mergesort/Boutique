import Boutique

extension Store where Item == Note {
    static let notesStore = Store<Note>(
        storage: SQLiteStorageEngine.default(appendingPath: "RelationshipDemo/Notes"),
        cacheIdentifier: \.id
    )
}

extension Store where Item == Tag {
    static let tagsStore = Store<Tag>(
        storage: SQLiteStorageEngine.default(appendingPath: "RelationshipDemo/Tags"),
        cacheIdentifier: \.id
    )
}

extension Store where Item == ActionLog {
    static let actionLogStore = Store<ActionLog>(
        storage: SQLiteStorageEngine.default(appendingPath: "RelationshipDemo/Actions"),
        cacheIdentifier: \.id
    )
}
