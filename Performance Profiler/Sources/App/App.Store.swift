import Boutique

extension Store where Item == RichNote {

    static let notesStore = Store<RichNote>(
        directory: .documents(appendingPath: "Items"),
        cacheIdentifier: \.id
    )

}
