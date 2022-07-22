public extension Store {

    class Operation {
        private let store: Store
        private var committed = false
        private var operations = [(Store) -> Void]()

        internal init(store: Store) {
            self.store = store
        }

        deinit {
            print("Entered deinit", self.operations)
            self.run()
            print("We ran!", self.operations)
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
            self.operations.append { _ in print("+\(item)") }
            return self
        }

        @discardableResult
        func add(_ items: [Item]) async throws -> Operation {
            self.operations.append { _ in print("+\(items)") }
            return self
        }

        @discardableResult
        func remove(_ item: Item) async throws -> Operation {
            self.operations.append { _ in print("-\(item)") }
            return self
        }

        @discardableResult
        func remove(_ items: [Item]) async throws -> Operation {
            self.operations.append { _ in print("-\(items)") }
            return self
        }

        @discardableResult
        func removeAll() async throws -> Operation {
            self.operations.append { _ in print("--all") }
            return self
        }

    }
}
