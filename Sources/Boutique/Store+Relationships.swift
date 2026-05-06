import Foundation

/// A Store operation that can trigger relationships from one Store to another.
public enum StoreRelationshipEvent: Sendable {
    /// The parent Store updated one or more existing items.
    case update

    /// The parent Store removed one or more items.
    case remove
}

/// An error thrown when a Store relationship fails while propagating changes.
public struct StoreRelationshipError: Error {
    /// The Store operation that triggered the relationship.
    public let event: StoreRelationshipEvent

    /// The relationship action that failed.
    public let action: String

    /// The type name of the Store where the relationship started.
    public let parentItemType: String

    /// The type name of the Store that relationship propagation attempted to update.
    public let childItemType: String

    /// The number of parent changes that triggered relationship propagation.
    public let affectedParentChangeCount: Int

    /// The underlying error thrown while updating the child Store.
    public let underlyingError: any Error
}

extension StoreRelationshipError: LocalizedError {
    public var errorDescription: String? {
        "Failed to propagate \(self.action) relationship from \(self.parentItemType) to \(self.childItemType) after \(self.event) for \(self.affectedParentChangeCount) change(s): \(self.underlyingError)"
    }
}

public extension Store {
    /// Adds a relationship that updates parent values in a child Store's array property.
    ///
    /// Use this overload when the child model embeds parent values in an array, such as a `RichLink`
    /// storing `[Tag]`. When matching parent values are updated in this Store, Boutique updates each
    /// child array and inserts the changed children back into the child Store as one batch.
    ///
    /// ```swift
    /// tagsStore.addRelationship(updating: \.tags, in: richLinksStore)
    /// ```
    func addRelationship<Child: StorableItem>(updating childValues: WritableKeyPath<Child, [Item]>, in childStore: Store<Child>) where Item: Equatable {
        self.relationships.append(
            AnyStoreRelationship(
                event: .update,
                action: "update",
                childItemType: String(describing: Child.self),
                propagate: { changes in
                    try await childStore.update(changes, in: childValues)
                }
            )
        )
    }

    /// Adds a relationship that updates parent values in a child Store's optional property.
    ///
    /// Use this overload when the child model stores one optional parent value, such as a `RichLink`
    /// storing `primaryTag: Tag?`. When matching parent values are updated in this Store, Boutique
    /// updates each child optional value and inserts the changed children back into the child Store as
    /// one batch.
    ///
    /// ```swift
    /// tagsStore.addRelationship(updating: \.primaryTag, in: richLinksStore)
    /// ```
    func addRelationship<Child: StorableItem>(updating childValue: WritableKeyPath<Child, Item?>, in childStore: Store<Child>) where Item: Equatable {
        self.relationships.append(
            AnyStoreRelationship(
                event: .update,
                action: "update",
                childItemType: String(describing: Child.self),
                propagate: { changes in
                    try await childStore.update(changes, at: childValue)
                }
            )
        )
    }

    /// Adds a relationship that clears removed parent values from a child Store's array property.
    ///
    /// Use this overload when the child model embeds parent values in an array, such as a `RichLink`
    /// storing `[Tag]`. When matching parent values are removed from this Store, Boutique removes them
    /// from each child array and inserts the changed children back into the child Store as one batch.
    ///
    /// ```swift
    /// tagsStore.addRelationship(clearing: \.tags, in: richLinksStore)
    /// ```
    func addRelationship<Child: StorableItem>(clearing childValues: WritableKeyPath<Child, [Item]>, in childStore: Store<Child>) where Item: Equatable {
        self.relationships.append(
            AnyStoreRelationship(
                event: .remove,
                action: "clear",
                childItemType: String(describing: Child.self),
                propagate: { changes in
                    try await childStore.clear(changes.map(\.oldValue), from: childValues)
                }
            )
        )
    }

    /// Adds a relationship that nullifies removed parent values from a child Store's optional property.
    ///
    /// Use this overload when the child model stores one optional parent value, such as a `RichLink`
    /// storing `primaryTag: Tag?`. The `WritableKeyPath<Child, Item?>` parameter ensures nullification
    /// is only available for optional child properties.
    ///
    /// ```swift
    /// tagsStore.addRelationship(nullifying: \.primaryTag, in: richLinksStore)
    /// ```
    func addRelationship<Child: StorableItem>(nullifying childValue: WritableKeyPath<Child, Item?>, in childStore: Store<Child>) where Item: Equatable {
        self.relationships.append(
            AnyStoreRelationship(
                event: .remove,
                action: "nullify",
                childItemType: String(describing: Child.self),
                propagate: { changes in
                    try await childStore.nullify(changes.map(\.oldValue), at: childValue)
                }
            )
        )
    }

    /// Adds a relationship that runs a custom closure when this Store updates or removes parent values.
    ///
    /// Use this overload when a relationship needs custom behavior beyond the built-in key-path
    /// relationships. Boutique passes the parent changes and the related child Store into the closure.
    ///
    /// ```swift
    /// tagsStore.addRelationship(to: richLinksStore, on: .update) { changes, richLinksStore in
    ///     print("Updated \(changes.count) tag(s) for \(richLinksStore.items.count) rich link(s).")
    /// }
    /// ```
    func addRelationship<Child: StorableItem>(to childStore: Store<Child>, on event: StoreRelationshipEvent, perform action: @escaping @MainActor ([StoreRelationshipChange<Item>], Store<Child>) async throws -> Void) {
        self.relationships.append(
            AnyStoreRelationship(
                event: event,
                action: "custom",
                childItemType: String(describing: Child.self),
                propagate: { changes in
                    try await action(changes, childStore)
                }
            )
        )
    }
}

/// A parent Store value change that triggered relationship propagation.
public struct StoreRelationshipChange<Item: StorableItem>: Sendable {
    /// The parent value before the triggering operation.
    public let oldValue: Item

    /// The parent value after the triggering operation.
    public let newValue: Item
}

internal struct AnyStoreRelationship<Parent: StorableItem> {
    let event: StoreRelationshipEvent
    let action: String
    let childItemType: String
    let propagate: @MainActor ([StoreRelationshipChange<Parent>]) async throws -> Void
}

private extension Store {
    func update<Parent: Equatable>(_ changes: [StoreRelationshipChange<Parent>], in childValues: WritableKeyPath<Item, [Parent]>) async throws {
        let updatedChildren = self.items.compactMap { child -> Item? in
            var updatedChild = child
            let originalValues = updatedChild[keyPath: childValues]

            for change in changes {
                updatedChild[keyPath: childValues].replace(change.oldValue, with: change.newValue)
            }

            guard updatedChild[keyPath: childValues] != originalValues else { return nil }
            return updatedChild
        }

        guard !updatedChildren.isEmpty else { return }

        try await self.insert(updatedChildren)
    }

    func update<Parent: Equatable>(_ changes: [StoreRelationshipChange<Parent>], at childValue: WritableKeyPath<Item, Parent?>) async throws {
        let updatedChildren = self.items.compactMap { child -> Item? in
            guard let value = child[keyPath: childValue], let change = changes.first(where: { $0.oldValue == value }) else { return nil }

            var updatedChild = child
            updatedChild[keyPath: childValue] = change.newValue
            return updatedChild
        }

        guard !updatedChildren.isEmpty else { return }

        try await self.insert(updatedChildren)
    }

    func clear<Parent: Equatable>(_ parentItems: [Parent], from childValues: WritableKeyPath<Item, [Parent]>) async throws {
        let updatedChildren = self.items.compactMap { child -> Item? in
            var updatedChild = child
            let originalValues = updatedChild[keyPath: childValues]
            updatedChild[keyPath: childValues].removeAll(where: parentItems.contains)

            guard updatedChild[keyPath: childValues] != originalValues else { return nil }
            return updatedChild
        }

        guard !updatedChildren.isEmpty else { return }

        try await self.insert(updatedChildren)
    }

    func nullify<Parent: Equatable>(_ parentItems: [Parent], at childValue: WritableKeyPath<Item, Parent?>) async throws {
        let updatedChildren = self.items.compactMap { child -> Item? in
            guard let value = child[keyPath: childValue], parentItems.contains(value) else { return nil }

            var updatedChild = child
            updatedChild[keyPath: childValue] = nil
            return updatedChild
        }

        guard !updatedChildren.isEmpty else { return }

        try await self.insert(updatedChildren)
    }
}

private extension Array where Element: Equatable {
    mutating func replace(_ oldValue: Element, with newValue: Element) {
        for index in self.indices where self[index] == oldValue {
            self[index] = newValue
        }
    }
}
