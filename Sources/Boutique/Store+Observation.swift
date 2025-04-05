import SwiftUI

public extension View {
    func onStoreDidLoad<StorableItem: Codable & Sendable>(_ store: Store<StorableItem>, onLoad: @escaping () -> Void, onError: ((Error) -> Void)? = nil) -> some View {
        self.task({
            do {
                try await store.itemsHaveLoaded()
                onLoad()
            } catch {
                onError?(error)
            }
        })
    }

    func onStoreDidLoad<StorableItem: Codable & Sendable>(_ store: Store<StorableItem>, update hasLoadedState: Binding<Bool>, onError: ((Error) -> Void)? = nil) -> some View {
        self.task({
            do {
                try await store.itemsHaveLoaded()
                hasLoadedState.wrappedValue = true
            } catch {
                onError?(error)
            }
        })
    }
}
