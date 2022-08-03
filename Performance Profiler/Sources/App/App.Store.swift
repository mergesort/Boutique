import Boutique

extension Store where Item == RichNote {
    static let notesStore = Store<RichNote>(cacheIdentifier: \.id)
}
