public extension Store {

    /// An operation is a type that allows you to stack ``insert(_:)-7z2oe``,
    /// ``remove(_:)-8ufsb``, or ``removeAll()-1xc24`` calls in a chained manner.
    ///
    /// This allows for simple fluent syntax such as `store.removeAll().insert(items)`, rather than having
    /// them be split over two operations, and making two separate dispatches to the `@MainActor`.
    /// (Dispatching to the main actor multiple times can lead to users seeing odd visual experiences
    /// in SwiftUI apps, which is why Boutique goes to great lengths to help avoid that.)
    final class Operation {

        private let store: Store
        private var operationsHaveRun = false
        private var operations = [ExecutableAction]()

        internal init(store: Store) {
            self.store = store
        }

        /// Adds an item to the ``Store``.
        ///
        /// When an item is inserted with the same `cacheIdentifier` as an item that already exists in the ``Store``
        /// the item being inserted will replace the item in the ``Store``. You can think of the ``Store`` as a bag
        /// of items, removing complexity when it comes to managing items, indices, and more,
        /// but it also means you need to choose well thought out and uniquely identifying `cacheIdentifier`s.
        /// - Parameters:
        ///   - item: The item you are adding to the ``Store``.
        @available(
            *, deprecated,
             renamed: "insert",
             message: "This method is functionally equivalent to `insert` and will be removed in a future release. After using Boutique in practice for a while I decided that insert was a more semantically correct name for this operation on a Store, if you'd like to learn more you can see the discussion here. https://github.com/mergesort/Boutique/discussions/36"
        )
        public func add(_ item: Item) async throws -> Operation {
            try await self.insert(item)
        }

        /// Inserts an item into the ``Store``.
        ///
        /// When an item is inserted with the same `cacheIdentifier` as an item that already exists in the ``Store``
        /// the item being inserted will replace the item in the ``Store``. You can think of the ``Store`` as a bag
        /// of items, removing complexity when it comes to managing items, indices, and more,
        /// but it also means you need to choose well thought out and uniquely identifying `cacheIdentifier`s.
        /// - Parameters:
        ///   - item: The item you are inserting into the ``Store``.
        public func insert(_ item: Item) async throws -> Operation {
            if case .removeItems(let removedItems) = self.operations.last?.action {
                self.operations.removeLast()

                self.operations.append(ExecutableAction(action: .insert, executable: {
                    try await $0.performInsert(item, firstRemovingExistingItems: .items(removedItems))
                }))
            } else if case .removeAll = self.operations.last?.action {
                self.operations.removeLast()

                self.operations.append(ExecutableAction(action: .insert, executable: {
                    try await $0.performInsert(item, firstRemovingExistingItems: .all)
                }))
            } else {
                self.operations.append(ExecutableAction(action: .insert, executable: {
                    try await $0.performInsert(item)
                }))
            }

            return self
        }

        /// Adds an array of items to the ``Store``.
        ///
        /// Prefer inserting multiple items using this method instead of calling ``insert(_:)-1nu61``
        /// multiple times to avoid making multiple separate dispatches to the `@MainActor`.
        /// - Parameters:
        ///   - items: The items to add to the store.
        @available(
            *, deprecated,
             renamed: "insert",
             message: "This method is functionally equivalent to `insert` and will be removed in a future release. After using Boutique in practice for a while I decided that insert was a more semantically correct name for this operation on a Store, if you'd like to learn more you can see the discussion here. https://github.com/mergesort/Boutique/discussions/36"
        )
        public func add(_ items: [Item]) async throws -> Operation {
            try await self.insert(items)
        }

        /// Inserts an array of items into the ``Store``.
        ///
        /// Prefer inserting multiple items using this method instead of calling ``insert(_:)-1nu61``
        /// multiple times to avoid making multiple separate dispatches to the `@MainActor`.
        /// - Parameters:
        ///   - items: The items to insert into the store.
        public func insert(_ items: [Item]) async throws -> Operation {
            if case .removeItems(let removedItems) = self.operations.last?.action {
                self.operations.removeLast()

                self.operations.append(ExecutableAction(action: .insert, executable: {
                    try await $0.performInsert(items, firstRemovingExistingItems: .items(removedItems))
                }))
            } else if case .removeAll = self.operations.last?.action {
                self.operations.removeLast()

                self.operations.append(ExecutableAction(action: .insert, executable: {
                    try await $0.performInsert(items, firstRemovingExistingItems: .all)
                }))
            } else {
                self.operations.append(ExecutableAction(action: .insert, executable: {
                    try await $0.performInsert(items)
                }))
            }

            return self
        }

        /// Removes an item from the ``Store``.
        /// - Parameter item: The item you are removing from the ``Store``.
        public func remove(_ item: Item) async throws -> Operation {
            self.operations.append(ExecutableAction(action: .removeItem(item), executable: {
                try await $0.performRemove(item)
            }))

            return self
        }

        /// Removes a list of items from the ``Store``.
        ///
        /// Prefer removing multiple items using this method instead of calling ``remove(_:)-8ufsb``
        /// multiple times to avoid making multiple separate dispatches to the `@MainActor`.
        /// - Parameter item: The items you are removing from the `Store`.
        public func remove(_ items: [Item]) async throws -> Operation {
            self.operations.append(ExecutableAction(action: .removeItems(items), executable: {
                try await $0.performRemove(items)
            }))

            return self
        }

        /// Removes all items from the ``Store``'s memory cache and StorageEngine.
        ///
        /// A separate method you should use when removing all data rather than calling
        /// ``remove(_:)-8ufsb`` or ``remove(_:)-2tqlz`` multiple times.
        /// This method handles removing all of the data in one operation rather than iterating over every item
        /// in the ``Store``, avoiding multiple dispatches to the `@MainActor`, with far better performance.
        public func removeAll() async throws -> Operation {
            self.operations.append(ExecutableAction(action: .removeAll, executable: {
                try await $0.performRemoveAll()
            }))

            return self
        }

        /// A function that runs a series of chained operations.
        ///
        /// If you create an `Operation` chain you must manually invoke ``run()`` for the operations to execute.
        /// If you do not then each `Operation` will be created, but not executed.
        public func run() async throws {
            guard !self.operationsHaveRun else { return }

            self.operationsHaveRun = true

            for operation in self.operations {
                try await operation.executable(self.store)
            }
        }

    }
}

private extension Store.Operation {

    struct ExecutableAction {
        let action: Action
        let executable: (Store) async throws -> Void
    }

    enum Action {
        case insert
        case removeItem(_ item: Item)
        case removeItems(_ items: [Item])
        case removeAll
    }

}
