public extension Store {

    class Operation {
        private let store: Store
        private var committed = false
        private var operations = [(Store) -> Void]()

        internal init(store: Store) {
            self.store = store
        }

        deinit {
            self.run()
        }

        public func run() {
            guard !self.committed else { return }

            self.committed = true

            for operation in self.operations {
                operation(self.store)
            }
        }

        @discardableResult
        func add(_ item: Item) async throws -> Operation {
            try await store.add(item: item)
            return self
        }

        @discardableResult
        func add(_ items: [Item]) async throws -> Operation {
            try await store.add(items: items)
            return self
        }

        @discardableResult
        func remove(_ item: Item) async throws -> Operation {
            try await store.removeItem(item)
            return self
        }

        @discardableResult
        func remove(_ items: [Item]) async throws -> Operation {
            try await store.removeItems(items)
            return self
        }

        @discardableResult
        func removeAll() async throws -> Operation {
            try await store.removeAllItems()
            return self
        }

    }
}
