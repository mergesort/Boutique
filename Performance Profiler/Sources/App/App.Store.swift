import Boutique

extension Store where Item == RichNote {

    static let notesStore = Store<RichNote>(
        storagePath: Store<RichNote>.documentsDirectory(appendingPath: "Items"),
        cacheIdentifier: \.id
    )

}
