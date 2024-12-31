import SwiftUI

public extension View {
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    /// Observes whether a ``Store`` has finished loading it's items.
    ///
    /// - Parameters:
    ///   - store: The ``Store`` whose loading is being observed.
    ///   - onLoad: The closure to call when the ``Store`` has finished loading.
    ///   - onError: The closure to call if an error occurs and the ``Store`` is not loaded.
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

    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    /// Observes whether a ``Store`` has finished loading it's items.
    ///
    /// - Parameters:
    ///   - store: The ``Store`` whose loading is being observed.
    ///   - update: A binding to that will be updated when the ``Store`` has finished loading.
    ///   - onError: The closure to call if an error occurs and the ``Store`` is not loaded.
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
