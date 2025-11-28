import Foundation

// MARK: - Relationship Event Types

/// Specifies when a relationship action should be triggered.
public enum RelationshipEvent {
    /// Triggered when items are inserted into the parent store.
    case onInsert

    /// Triggered when items are removed from the parent store.
    case onRemove

    /// Triggered when items are either inserted or removed from the parent store.
    case onChange
}

// MARK: - Relationship Actions

/// Specifies what action to take on the child store when a relationship event occurs.
public enum RelationshipAction {
    /// Removes the parent item from the child's property (from array or sets optional to nil).
    case nullify

    /// Deletes the entire child item from the store if it references the parent.
    case delete

    /// Updates the child's property to match the parent (typically used with .onInsert).
    case update
}

// MARK: - Store Relationships

public extension Store {
    /// Adds a relationship between this store (parent) and another store (child).
    ///
    /// Relationships allow you to keep data in sync between denormalized stores.
    /// When items in the parent store change, the specified action will be performed
    /// on related items in the child store.
    ///
    /// Example:
    /// ```swift
    /// // When a Tag is removed, remove it from all RichLink.tags arrays
    /// tagsStore.addRelationship(
    ///     when: .onRemove,
    ///     to: richLinksStore,
    ///     via: \.tags,
    ///     action: .nullify
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - event: When the relationship action should trigger (.onInsert, .onRemove, or .onChange)
    ///   - childStore: The store containing items that reference this store's items
    ///   - keyPath: A keypath from the child item to an array of parent items
    ///   - action: What action to perform on the child store
    ///   - compareUsing: Optional custom comparison closure. Defaults to comparing cache identifiers.
    func addRelationship<ChildItem>(
        when event: RelationshipEvent,
        to childStore: Store<ChildItem>,
        via keyPath: WritableKeyPath<ChildItem, [Item]>,
        action: RelationshipAction,
        compareUsing comparison: ((Item, Item) -> Bool)? = nil
    ) where ChildItem: StorableItem {
        let relationship = ArrayRelationship(
            parentStore: self,
            childStore: childStore,
            keyPath: keyPath,
            event: event,
            action: action,
            comparison: comparison ?? self.defaultComparison(_:_:)
        )

        relationship.activate()
    }

    /// Adds a relationship between this store (parent) and another store (child) for optional properties.
    ///
    /// - Parameters:
    ///   - event: When the relationship action should trigger (.onInsert, .onRemove, or .onChange)
    ///   - childStore: The store containing items that reference this store's items
    ///   - keyPath: A keypath from the child item to an optional parent item
    ///   - action: What action to perform on the child store
    ///   - compareUsing: Optional custom comparison closure. Defaults to comparing cache identifiers.
    func addRelationship<ChildItem>(
        when event: RelationshipEvent,
        to childStore: Store<ChildItem>,
        via keyPath: WritableKeyPath<ChildItem, Item?>,
        action: RelationshipAction,
        compareUsing comparison: ((Item, Item) -> Bool)? = nil
    ) where ChildItem: StorableItem {
        let relationship = OptionalRelationship(
            parentStore: self,
            childStore: childStore,
            keyPath: keyPath,
            event: event,
            action: action,
            comparison: comparison ?? self.defaultComparison(_:_:)
        )

        relationship.activate()
    }

    /// Adds a relationship between this store (parent) and another store (child) for non-optional properties.
    ///
    /// - Parameters:
    ///   - event: When the relationship action should trigger (.onInsert, .onRemove, or .onChange)
    ///   - childStore: The store containing items that reference this store's items
    ///   - keyPath: A keypath from the child item to a parent item
    ///   - action: What action to perform on the child store
    ///   - compareUsing: Optional custom comparison closure. Defaults to comparing cache identifiers.
    func addRelationship<ChildItem>(
        when event: RelationshipEvent,
        to childStore: Store<ChildItem>,
        via keyPath: WritableKeyPath<ChildItem, Item>,
        action: RelationshipAction,
        compareUsing comparison: ((Item, Item) -> Bool)? = nil
    ) where ChildItem: StorableItem {
        let relationship = RequiredRelationship(
            parentStore: self,
            childStore: childStore,
            keyPath: keyPath,
            event: event,
            action: action,
            comparison: comparison ?? self.defaultComparison(_:_:)
        )

        relationship.activate()
    }
}

// MARK: - Default Comparison

private extension Store {
    /// Default comparison function that compares items using their cache identifiers.
    func defaultComparison(_ lhs: Item, _ rhs: Item) -> Bool {
        return lhs[keyPath: self.cacheIdentifier] == rhs[keyPath: self.cacheIdentifier]
    }
}

// MARK: - Relationship Protocol

@MainActor
private protocol Relationship: AnyObject {
    func activate()
    func deactivate()
}

// MARK: - Array Relationship

@MainActor
private final class ArrayRelationship<ParentItem: StorableItem, ChildItem: StorableItem>: Relationship {
    private let parentStore: Store<ParentItem>
    private let childStore: Store<ChildItem>
    private let keyPath: WritableKeyPath<ChildItem, [ParentItem]>
    private let event: RelationshipEvent
    private let action: RelationshipAction
    private let comparison: (ParentItem, ParentItem) -> Bool

    private var observationTask: Task<Void, Never>?

    init(
        parentStore: Store<ParentItem>,
        childStore: Store<ChildItem>,
        keyPath: WritableKeyPath<ChildItem, [ParentItem]>,
        event: RelationshipEvent,
        action: RelationshipAction,
        comparison: @escaping (ParentItem, ParentItem) -> Bool
    ) {
        self.parentStore = parentStore
        self.childStore = childStore
        self.keyPath = keyPath
        self.event = event
        self.action = action
        self.comparison = comparison
    }

    func activate() {
        observationTask = Task { @MainActor in
            for await storeEvent in parentStore.events {
                await handleEvent(storeEvent)
            }
        }
    }

    func deactivate() {
        observationTask?.cancel()
        observationTask = nil
    }

    private func handleEvent(_ storeEvent: StoreEvent<ParentItem>) async {
        switch (event, storeEvent.operation) {
        case (.onInsert, .insert):
            await handleInsert(storeEvent.items)
        case (.onRemove, .remove):
            await handleRemove(storeEvent.items)
        case (.onChange, .insert):
            await handleInsert(storeEvent.items)
        case (.onChange, .remove):
            await handleRemove(storeEvent.items)
        default:
            break
        }
    }

    private func handleInsert(_ insertedItems: [ParentItem]) async {
        guard action == .update else { return }

        // For each inserted parent item, find child items that reference it and update them
        var childItemsToUpdate: [ChildItem] = []

        for childItem in childStore.items {
            var updatedChildItem = childItem
            var hasChanges = false

            let relatedItems = childItem[keyPath: keyPath]
            var updatedRelatedItems = relatedItems

            for insertedItem in insertedItems {
                // Find if this child references the inserted parent
                if let index = relatedItems.firstIndex(where: { comparison($0, insertedItem) }) {
                    // Update the reference to the latest version
                    updatedRelatedItems[index] = insertedItem
                    hasChanges = true
                }
            }

            if hasChanges {
                updatedChildItem[keyPath: keyPath] = updatedRelatedItems
                childItemsToUpdate.append(updatedChildItem)
            }
        }

        if !childItemsToUpdate.isEmpty {
            try? await childStore.insert(childItemsToUpdate)
        }
    }

    private func handleRemove(_ removedItems: [ParentItem]) async {
        switch action {
        case .nullify:
            await nullifyRemovedItems(removedItems)
        case .delete:
            await deleteChildrenWithRemovedItems(removedItems)
        case .update:
            break
        }
    }

    private func nullifyRemovedItems(_ removedItems: [ParentItem]) async {
        var childItemsToUpdate: [ChildItem] = []

        for childItem in childStore.items {
            let relatedItems = childItem[keyPath: keyPath]

            // Filter out the removed parent items
            let updatedRelatedItems = relatedItems.filter { relatedItem in
                !removedItems.contains(where: { comparison($0, relatedItem) })
            }

            // Only update if the array changed
            if updatedRelatedItems.count != relatedItems.count {
                var updatedChildItem = childItem
                updatedChildItem[keyPath: keyPath] = updatedRelatedItems
                childItemsToUpdate.append(updatedChildItem)
            }
        }

        if !childItemsToUpdate.isEmpty {
            try? await childStore.insert(childItemsToUpdate)
        }
    }

    private func deleteChildrenWithRemovedItems(_ removedItems: [ParentItem]) async {
        var childItemsToDelete: [ChildItem] = []

        for childItem in childStore.items {
            let relatedItems = childItem[keyPath: keyPath]

            // If this child references any of the removed parents, delete it
            let referencesRemovedItem = relatedItems.contains { relatedItem in
                removedItems.contains(where: { comparison($0, relatedItem) })
            }

            if referencesRemovedItem {
                childItemsToDelete.append(childItem)
            }
        }

        if !childItemsToDelete.isEmpty {
            try? await childStore.remove(childItemsToDelete)
        }
    }
}

// MARK: - Optional Relationship

@MainActor
private final class OptionalRelationship<ParentItem: StorableItem, ChildItem: StorableItem>: Relationship {
    private let parentStore: Store<ParentItem>
    private let childStore: Store<ChildItem>
    private let keyPath: WritableKeyPath<ChildItem, ParentItem?>
    private let event: RelationshipEvent
    private let action: RelationshipAction
    private let comparison: (ParentItem, ParentItem) -> Bool

    private var observationTask: Task<Void, Never>?

    init(
        parentStore: Store<ParentItem>,
        childStore: Store<ChildItem>,
        keyPath: WritableKeyPath<ChildItem, ParentItem?>,
        event: RelationshipEvent,
        action: RelationshipAction,
        comparison: @escaping (ParentItem, ParentItem) -> Bool
    ) {
        self.parentStore = parentStore
        self.childStore = childStore
        self.keyPath = keyPath
        self.event = event
        self.action = action
        self.comparison = comparison
    }

    func activate() {
        observationTask = Task { @MainActor in
            for await storeEvent in parentStore.events {
                await handleEvent(storeEvent)
            }
        }
    }

    func deactivate() {
        observationTask?.cancel()
        observationTask = nil
    }

    private func handleEvent(_ storeEvent: StoreEvent<ParentItem>) async {
        switch (event, storeEvent.operation) {
        case (.onInsert, .insert):
            await handleInsert(storeEvent.items)
        case (.onRemove, .remove):
            await handleRemove(storeEvent.items)
        case (.onChange, .insert):
            await handleInsert(storeEvent.items)
        case (.onChange, .remove):
            await handleRemove(storeEvent.items)
        default:
            break
        }
    }

    private func handleInsert(_ insertedItems: [ParentItem]) async {
        guard action == .update else { return }

        var childItemsToUpdate: [ChildItem] = []

        for childItem in childStore.items {
            if let relatedItem = childItem[keyPath: keyPath] {
                // Check if this child references any of the inserted parents
                if let insertedItem = insertedItems.first(where: { comparison($0, relatedItem) }) {
                    var updatedChildItem = childItem
                    updatedChildItem[keyPath: keyPath] = insertedItem
                    childItemsToUpdate.append(updatedChildItem)
                }
            }
        }

        if !childItemsToUpdate.isEmpty {
            try? await childStore.insert(childItemsToUpdate)
        }
    }

    private func handleRemove(_ removedItems: [ParentItem]) async {
        switch action {
        case .nullify:
            await nullifyRemovedItems(removedItems)
        case .delete:
            await deleteChildrenWithRemovedItems(removedItems)
        case .update:
            break
        }
    }

    private func nullifyRemovedItems(_ removedItems: [ParentItem]) async {
        var childItemsToUpdate: [ChildItem] = []

        for childItem in childStore.items {
            if let relatedItem = childItem[keyPath: keyPath] {
                // Check if this child references any of the removed parents
                let referencesRemovedItem = removedItems.contains(where: { comparison($0, relatedItem) })

                if referencesRemovedItem {
                    var updatedChildItem = childItem
                    updatedChildItem[keyPath: keyPath] = nil
                    childItemsToUpdate.append(updatedChildItem)
                }
            }
        }

        if !childItemsToUpdate.isEmpty {
            try? await childStore.insert(childItemsToUpdate)
        }
    }

    private func deleteChildrenWithRemovedItems(_ removedItems: [ParentItem]) async {
        var childItemsToDelete: [ChildItem] = []

        for childItem in childStore.items {
            if let relatedItem = childItem[keyPath: keyPath] {
                let referencesRemovedItem = removedItems.contains(where: { comparison($0, relatedItem) })

                if referencesRemovedItem {
                    childItemsToDelete.append(childItem)
                }
            }
        }

        if !childItemsToDelete.isEmpty {
            try? await childStore.remove(childItemsToDelete)
        }
    }
}

// MARK: - Required Relationship

@MainActor
private final class RequiredRelationship<ParentItem: StorableItem, ChildItem: StorableItem>: Relationship {
    private let parentStore: Store<ParentItem>
    private let childStore: Store<ChildItem>
    private let keyPath: WritableKeyPath<ChildItem, ParentItem>
    private let event: RelationshipEvent
    private let action: RelationshipAction
    private let comparison: (ParentItem, ParentItem) -> Bool

    private var observationTask: Task<Void, Never>?

    init(
        parentStore: Store<ParentItem>,
        childStore: Store<ChildItem>,
        keyPath: WritableKeyPath<ChildItem, ParentItem>,
        event: RelationshipEvent,
        action: RelationshipAction,
        comparison: @escaping (ParentItem, ParentItem) -> Bool
    ) {
        self.parentStore = parentStore
        self.childStore = childStore
        self.keyPath = keyPath
        self.event = event
        self.action = action
        self.comparison = comparison
    }

    func activate() {
        observationTask = Task { @MainActor in
            for await storeEvent in parentStore.events {
                await handleEvent(storeEvent)
            }
        }
    }

    func deactivate() {
        observationTask?.cancel()
        observationTask = nil
    }

    private func handleEvent(_ storeEvent: StoreEvent<ParentItem>) async {
        switch (event, storeEvent.operation) {
        case (.onInsert, .insert):
            await handleInsert(storeEvent.items)
        case (.onRemove, .remove):
            await handleRemove(storeEvent.items)
        case (.onChange, .insert):
            await handleInsert(storeEvent.items)
        case (.onChange, .remove):
            await handleRemove(storeEvent.items)
        default:
            break
        }
    }

    private func handleInsert(_ insertedItems: [ParentItem]) async {
        guard action == .update else { return }

        var childItemsToUpdate: [ChildItem] = []

        for childItem in childStore.items {
            let relatedItem = childItem[keyPath: keyPath]

            // Check if this child references any of the inserted parents
            if let insertedItem = insertedItems.first(where: { comparison($0, relatedItem) }) {
                var updatedChildItem = childItem
                updatedChildItem[keyPath: keyPath] = insertedItem
                childItemsToUpdate.append(updatedChildItem)
            }
        }

        if !childItemsToUpdate.isEmpty {
            try? await childStore.insert(childItemsToUpdate)
        }
    }

    private func handleRemove(_ removedItems: [ParentItem]) async {
        switch action {
        case .nullify:
            break
        case .delete:
            await deleteChildrenWithRemovedItems(removedItems)
        case .update:
            break
        }
    }

    private func deleteChildrenWithRemovedItems(_ removedItems: [ParentItem]) async {
        var childItemsToDelete: [ChildItem] = []

        for childItem in childStore.items {
            let relatedItem = childItem[keyPath: keyPath]
            let referencesRemovedItem = removedItems.contains(where: { comparison($0, relatedItem) })

            if referencesRemovedItem {
                childItemsToDelete.append(childItem)
            }
        }

        if !childItemsToDelete.isEmpty {
            try? await childStore.remove(childItemsToDelete)
        }
    }
}
