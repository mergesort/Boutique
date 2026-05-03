---
name: boutique-store
description: Create and use Boutique Store for Swift data persistence, including initialization, @Stored controllers, CRUD operations, operation chaining, and granular event monitoring. Use when persisting arrays of items, building data controllers, or working with Boutique's Store type.
---

# Boutique Store

Use this skill when you need to persist arrays of items using Boutique's `Store`, build `@Observable` data controllers with `@Stored`, chain store operations, or monitor granular store events.

## Prerequisites

- Boutique added as a dependency via Swift Package Manager.
- Models conform to `Codable`, `Sendable`, and `Identifiable` (recommended).
- iOS 17+ / macOS 14+ deployment target.
- Swift 6.2+ (Boutique uses `@MainActor` default isolation).

## Item Requirements

All items stored in a `Store` must conform to `StorableItem`, which is a typealias for `Codable & Sendable`.

```swift
struct Note: Codable, Sendable, Identifiable {
    let id: String
    let text: String
    let createdAt: Date
}
```

## Creating a Store

### Shortest form (Identifiable with String ID)

When your item conforms to `Identifiable` with `ID == String`, the `cacheIdentifier` is inferred automatically.

```swift
let store = Store<Note>(
    storage: SQLiteStorageEngine.default(appendingPath: "Notes")
)
```

### Identifiable with UUID ID

When `ID == UUID`, the store automatically converts to a string identifier.

```swift
struct Photo: Codable, Sendable, Identifiable {
    let id: UUID
    let url: URL
}

let store = Store<Photo>(
    storage: SQLiteStorageEngine.default(appendingPath: "Photos")
)
```

### Custom cache identifier

For items that are not `Identifiable` or need a custom key, provide a `KeyPath<Item, String>`.

```swift
struct Bookmark: Codable, Sendable {
    let url: URL
    let title: String
}

let store = Store<Bookmark>(
    storage: SQLiteStorageEngine.default(appendingPath: "Bookmarks"),
    cacheIdentifier: \.url.absoluteString
)
```

### Custom storage directory

```swift
let store = Store<Note>(
    storage: SQLiteStorageEngine(directory: .documents(appendingPath: "Notes"))!
)
```

### Async initialization (items loaded before returning)

```swift
let store = try await Store<Note>(
    storage: SQLiteStorageEngine.default(appendingPath: "Notes")
)
// store.items is already populated here
```

### Waiting for items to load after sync init

```swift
let store = Store<Note>(
    storage: SQLiteStorageEngine.default(appendingPath: "Notes")
)

// Later, when you need items to be ready:
try await store.itemsHaveLoaded()
let notes = store.items
```

## CRUD Operations

### Insert

```swift
// Single item
try await store.insert(note)

// Multiple items (preferred over calling insert in a loop)
try await store.insert([note1, note2, note3])
```

Inserting an item with the same `cacheIdentifier` as an existing item replaces it. The Store handles uniqueness automatically.

### Remove

```swift
// Single item
try await store.remove(note)

// Multiple items
try await store.remove([note1, note2])

// All items
try await store.removeAll()
```

### Read

```swift
let allNotes = store.items // [Note]
```

## Operation Chaining

Chain multiple operations into a single batch to avoid multiple `@MainActor` dispatches. This prevents flickering in SwiftUI.

```swift
// Clear stale cache and insert fresh data
try await store
    .removeAll()
    .insert(freshNotes)
    .run()

// Remove specific items and insert new ones
try await store
    .remove(outdatedNote)
    .insert(updatedNote)
    .run()
```

You **must** call `.run()` at the end of a chain. Without it, the operations are created but never executed.

## Building @Observable Controllers with @Stored

The `@Stored` property wrapper connects a `Store` to an `@Observable` class, exposing items as a plain `[Item]` array and projecting the underlying `Store` via `$`.

### Standard pattern

```swift
@Observable
final class NotesController {
    @ObservationIgnored
    @Stored var notes: [Note]

    init(store: Store<Note>) {
        self._notes = Stored(in: store)
    }

    func fetchNotes() async throws {
        let notes = try await self.fetchNotesFromServer()
        try await self.$notes.insert(notes)
    }

    func addNote(_ note: Note) async throws {
        try await self.createNoteOnServer(note)
        try await self.$notes.insert(note)
    }

    func removeNote(_ note: Note) async throws {
        try await self.deleteNoteOnServer(note)
        try await self.$notes.remove(note)
    }

    func clearAllNotes() async throws {
        try await self.deleteAllNotesOnServer()
        try await self.$notes.removeAll()
    }
}
```

### Key points

- `self.notes` gives you the `[Note]` array (the `wrappedValue`).
- `self.$notes` gives you the `Store<Note>` (the `projectedValue`) for calling `insert`, `remove`, `removeAll`.
- **Always** mark `@Stored` with `@ObservationIgnored` inside `@Observable` classes to prevent duplicate observation tracking.
- Inject the `Store` via `init` for testability.

### Creating the store and controller

```swift
extension Store where Item == Note {
    static let notesStore = Store<Note>(
        storage: SQLiteStorageEngine.default(appendingPath: "Notes")
    )
}

// At your app's entry point or in a DI container
let notesController = NotesController(store: .notesStore)
```

## Granular Event Monitoring

The `events` property provides an `AsyncStream<StoreEvent<Item>>` for observing specific operations.

```swift
func monitorNotesEvents() async {
    for await event in notesController.$notes.events {
        switch event.operation {
        case .initialized:
            print("Store initialized")

        case .loaded:
            print("Loaded \(event.items.count) notes from disk")

        case .insert:
            print("Inserted notes:", event.items)

        case .remove:
            print("Removed notes:", event.items)
        }
    }
}
```

### StoreEvent operations

| Operation      | When it fires                        | `event.items` contains            |
|----------------|--------------------------------------|-----------------------------------|
| `.initialized` | Store created, before loading        | Empty array                       |
| `.loaded`      | Items loaded from storage engine     | All loaded items                  |
| `.insert`      | After `insert` completes             | The newly inserted items          |
| `.remove`      | After `remove`/`removeAll` completes | The removed items                 |

## Common Patterns

### Refresh cache from API

```swift
func refreshNotes() async throws {
    let freshNotes = try await self.api.fetchAllNotes()
    try await self.$notes
        .removeAll()
        .insert(freshNotes)
        .run()
}
```

### Static store definitions

```swift
extension Store where Item == Note {
    static let notesStore = Store<Note>(
        storage: SQLiteStorageEngine.default(appendingPath: "Notes")
    )
}

extension Store where Item == Photo {
    static let photosStore = Store<Photo>(
        storage: SQLiteStorageEngine.default(appendingPath: "Photos")
    )
}
```

## Notes

- All `Store` operations are `@MainActor` isolated and `async throws`.
- Items are persisted to SQLite automatically on every insert/remove.
- The Store uses an `OrderedDictionary` internally so item order is preserved.
- Prefer `insert([items])` over looping `insert(item)` to batch `@MainActor` dispatches.
- See `boutique-swiftui` skill for integrating stores with SwiftUI views.
- See `boutique-best-practices` skill for testing patterns with `Store.previewStore`.
