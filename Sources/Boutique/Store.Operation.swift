public extension Store {

    /// An operation is a function that allows you to stack `add()`, `remove()`, or `removeAll()`
    /// calls in a chained manner.
    ///
    /// This allows for simple fluent syntax such as `store.removeAll().add(items)`, rather than having
    /// them be split over two operations, and making two separate dispatches to the `@MainActor`.
    /// (Dispatching to the main actor multiple times can lead to users seeing odd visual experiences
    /// in SwiftUI apps, which is why Boutique goes to great lengths to help avoid that.)
    final class Operation {

        private let store: Store
        private var committed = false
        private var operations = [(Store) -> Void]()

        internal init(store: Store) {
            self.store = store
        }

        deinit {
            self.run()
        }

        /// Adds an item to the store.
        ///
        /// When an item is inserted with the same `cacheIdentifier` as an item that already exists in the `Store`
        /// the item being inserted will replace the item in the `Store`. You can think of the `Store` as a bag
        /// of items, removing complexity when it comes to managing items, indices, and more,
        /// but it also means you need to choose well thought out and uniquely identifying `cacheIdentifier`s.
        /// - Parameters:
        ///   - item: The item you are adding to the `Store`.
        @discardableResult
        public func add(_ item: Item) async throws -> Operation {
            try await store.performAdd(item)
            return self
        }

        /// Adds an array of items to the store.
        ///
        /// Prefer adding multiple items using this method instead of calling ``add(_:)-82sdc
        /// multiple times to avoid making multiple separate dispatches to the `@MainActor`.
        /// - Parameters:
        ///   - items: The items to add to the store.
        @discardableResult
        public func add(_ items: [Item]) async throws -> Operation {
            try await store.performAdd(items)
            return self
        }

        /// Removes an item from the store.
        /// - Parameter item: The item you are removing from the `Store`.
        @discardableResult
        public func remove(_ item: Item) async throws -> Operation {
            try await store.performRemove(item)
            return self
        }


        /// Removes a list of items from the store.
        ///
        /// Prefer removing multiple items using this method instead of calling ``remove(_:)-8ufsb``
        /// multiple times to avoid making multiple separate dispatches to the `@MainActor`.
        /// - Parameter item: The items you are removing from the `Store`.
        @discardableResult
        public func remove(_ items: [Item]) async throws -> Operation {
            try await store.performRemove(items)
            return self
        }

        /// Removes all items from the store's memory cache and storage engine.
        ///
        /// A separate method you should use when removing all data rather than calling
        /// ``remove(_:)-8ufsb`` or ``remove(_:)-2tqlz`` multiple times.
        /// This method handles removing all of the data in one operation rather than iterating over every item
        /// in the `Store`, avoiding multiple dispatches to the `@MainActor`, with far better performance.
        @discardableResult
        public func removeAll() async throws -> Operation {
            try await store.performRemoveAll()
            return self
        }

        /// A function that runs a series of chained operations.
        ///
        /// This function is automatically called on deinit, running them in the order they were chained together.
        /// You can also manually invoke `.run()` if you independently build a chain of `Operation`s
        /// and then wish to run them.
        public func run() {
            guard !self.committed else { return }

            self.committed = true

            for operation in self.operations {
                operation(self.store)
            }
        }

    }
}
