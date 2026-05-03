---
name: boutique-best-practices
description: Best practices for using Boutique with Swift 6 concurrency, @Observable, @ObservationIgnored, Sendable conformance, testing with preview stores, and dependency injection. Use when troubleshooting Boutique issues, migrating to Swift 6, or setting up tests.
---

# Boutique Best Practices

Use this skill when migrating to Swift 6, troubleshooting concurrency issues, setting up tests, or following Boutique's recommended patterns.

## Swift 6 and @MainActor Isolation

Boutique's `Store`, `StoredValue`, and `SecurelyStoredValue` are all `@MainActor` isolated. In Swift 6 with strict concurrency, this means:

- All store operations (`insert`, `remove`, `removeAll`) must be called from a `@MainActor` context.
- Controllers that use `@Stored`, `@StoredValue`, or `@SecurelyStoredValue` are implicitly `@MainActor` since the property wrappers are `@MainActor`.
- SwiftUI views are already `@MainActor`, so no extra annotation is needed there.

### Calling store operations from non-MainActor contexts

```swift
// From a background task or non-isolated function
func syncData() async throws {
    let data = try await self.api.fetchData() // Can run off main actor
    try await self.controller.updateStore(with: data) // MainActor hop happens automatically
}
```

## @ObservationIgnored (Critical)

When using `@Stored`, `@StoredValue`, or `@SecurelyStoredValue` inside an `@Observable` class, you **must** mark them with `@ObservationIgnored`.

### Why

`Store`, `StoredValue`, and `SecurelyStoredValue` are themselves `@Observable`. If you place an `@Observable` property inside another `@Observable` class without `@ObservationIgnored`, SwiftUI may track changes at both levels, leading to redundant view updates or unexpected behavior.

### Correct pattern

```swift
@Observable
final class NotesController {
    @ObservationIgnored
    @Stored var notes: [Note]

    init(store: Store<Note>) {
        self._notes = Stored(in: store)
    }
}

@Observable
final class Preferences {
    @ObservationIgnored
    @StoredValue(key: "theme")
    var theme: Theme = .light

    @ObservationIgnored
    @SecurelyStoredValue<String>(key: "authToken")
    var authToken
}
```

### Incorrect (missing @ObservationIgnored)

```swift
// DO NOT do this
@Observable
final class NotesController {
    @Stored var notes: [Note] // Missing @ObservationIgnored
}
```

## StorableItem Conformance

All items must conform to `StorableItem`, which is `Codable & Sendable`.

### Struct models (preferred)

Structs get `Sendable` conformance automatically when all stored properties are `Sendable`.

```swift
struct Note: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let text: String
    let createdAt: Date
}
```

### Enum models

Enums work as stored items too, as long as they conform to the required protocols.

```swift
enum Theme: String, Codable, Sendable, Equatable {
    case light
    case dark
    case system
}
```

## Dependency Injection for Testing

Always inject `Store` instances through initializers rather than creating them inline. This enables swapping in test stores.

### Production controller

```swift
@Observable
final class NotesController {
    @ObservationIgnored
    @Stored var notes: [Note]

    init(store: Store<Note>) {
        self._notes = Stored(in: store)
    }
}
```

### Static store definitions

```swift
extension Store where Item == Note {
    static let notesStore = Store<Note>(
        storage: SQLiteStorageEngine.default(appendingPath: "Notes")
    )
}
```

### Production usage

```swift
let controller = NotesController(store: .notesStore)
```

### Test usage

Create an in-memory store for test isolation. Use a unique temporary path per test to avoid collisions.

```swift
@Test
func testInsertNote() async throws {
    let store = Store<Note>(
        storage: SQLiteStorageEngine(directory: .temporary(appendingPath: UUID().uuidString))!
    )
    let controller = NotesController(store: store)
    try await store.itemsHaveLoaded()

    let note = Note(id: "1", text: "Test", createdAt: .now)
    try await controller.addNote(note)

    #expect(controller.notes.contains(where: { $0.id == note.id }))
}
```

## Preview Stores

For SwiftUI previews, use `Store.previewStore(items:)` (DEBUG only) to create in-memory stores with pre-populated data.

```swift
#Preview {
    let store = Store<Note>.previewStore(items: [
        Note(id: "1", text: "Preview note", createdAt: .now),
    ])

    NotesListView(notesController: NotesController(store: store))
}
```

Variants:
- `Store.previewStore(items:)` when `Item: Identifiable, ID == String`
- `Store.previewStore(items:)` when `Item: Identifiable, ID == UUID`
- `Store.previewStore(items:cacheIdentifier:)` for custom identifiers

Preview stores do **not** persist to disk and are only available in DEBUG builds.

## Common Mistakes and Fixes

### "set is inaccessible due to internal protection level"

You are calling `set` on the `wrappedValue` instead of the `projectedValue`. Add a `$` prefix.

```swift
// Wrong
storedValue.set(newValue)

// Correct
$storedValue.set(newValue)
```

### Double optional on @SecurelyStoredValue

`@SecurelyStoredValue` already wraps the value as optional. Do not declare the type as optional.

```swift
// Wrong: creates Item??
@SecurelyStoredValue<String?>(key: "token")
var token

// Correct: wrappedValue is String?
@SecurelyStoredValue<String>(key: "token")
var token
```

### Store items are empty on first access

The synchronous `Store` initializer loads items in a background task. If you access `store.items` immediately, it may be empty.

**Fix:** Use the async initializer, or call `itemsHaveLoaded()` before reading items.

```swift
// Option 1: Async init
let store = try await Store<Note>(storage: ...)

// Option 2: Wait for loading
let store = Store<Note>(storage: ...)
try await store.itemsHaveLoaded()
```

When using `@Stored` in a controller that's used by SwiftUI, items load automatically and the view re-renders when ready. Use `onStoreDidLoad` for explicit loading states.

### Forgetting .run() on operation chains

Chained operations are not executed until `.run()` is called.

```swift
// Operations created but never executed
try await store.removeAll().insert(items)

// Correct: executes the chain
try await store.removeAll().insert(items).run()
```

### Using insert in a loop instead of batch insert

```swift
// Inefficient: multiple @MainActor dispatches
for note in notes {
    try await store.insert(note)
}

// Correct: single batch operation
try await store.insert(notes)
```

## Architecture Recommendations

1. **One controller per domain**: Create focused `@Observable` controllers per data domain (`NotesController`, `PhotosController`), not one giant controller.
2. **Store as implementation detail**: Expose domain methods (`addNote`, `removeNote`) on controllers rather than exposing the `Store` directly to views.
3. **API-first, store-second**: Make API calls first, then sync to the local store on success. This keeps the store as a cache of server truth.
4. **Preferences as separate classes**: Break large preference objects into smaller `@Observable` classes grouped by feature area.

## Notes

- Boutique requires Swift 6.2+ and uses `@MainActor` default isolation.
- Minimum deployment targets are iOS 17 and macOS 14.
- Boutique depends on [Bodega](https://github.com/mergesort/Bodega) for its storage engine layer.
- See `boutique-store` skill for Store setup and @Stored controller patterns.
- See `boutique-stored-values` skill for @StoredValue and @SecurelyStoredValue APIs.
- See `boutique-swiftui` skill for SwiftUI view integration patterns.
