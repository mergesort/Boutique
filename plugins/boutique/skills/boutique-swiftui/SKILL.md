---
name: boutique-swiftui
description: Integrate Boutique with SwiftUI views using onChange, onStoreDidLoad, bindings, and preview stores. Use when building SwiftUI views that display or react to Boutique-persisted data.
---

# Boutique SwiftUI Integration

Use this skill when building SwiftUI views that display or react to data from Boutique's `Store`, `@StoredValue`, or `@SecurelyStoredValue`.

## Displaying Store Items in a View

Inject an `@Observable` controller as `@State` and access items directly.

```swift
struct NotesListView: View {
    @State var notesController: NotesController

    var body: some View {
        List(self.notesController.notes) { note in
            Text(note.text)
        }
    }
}
```

## Reacting to Store Changes with onChange

Use `.onChange(of:initial:)` to run code whenever the stored items change. The `initial: true` parameter ensures the closure also fires on first appearance.

```swift
struct NotesListView: View {
    @State var notesController: NotesController
    @State private var filteredNotes: [Note] = []

    var body: some View {
        List(self.filteredNotes) { note in
            Text(note.text)
        }
        .onChange(of: self.notesController.notes, initial: true) { _, newValue in
            self.filteredNotes = newValue.filter({ $0.text.count < 280 })
        }
    }
}
```

## Waiting for Store to Load with onStoreDidLoad

When a `Store` is initialized synchronously, items load in a background task. Use `onStoreDidLoad` to show loading states or trigger actions once items are ready.

### Callback-based

```swift
struct NotesView: View {
    @State var notesController: NotesController
    @State private var isLoaded = false

    var body: some View {
        Group {
            if self.isLoaded {
                NotesList(notes: self.notesController.notes)
            } else {
                ProgressView()
            }
        }
        .onStoreDidLoad(self.notesController.$notes, onLoad: {
            self.isLoaded = true
        }, onError: { error in
            print("Failed to load notes:", error)
        })
    }
}
```

### Binding-based

```swift
struct NotesView: View {
    @State var notesController: NotesController
    @State private var hasLoaded = false

    var body: some View {
        Group {
            if self.hasLoaded {
                NotesList(notes: self.notesController.notes)
            } else {
                ProgressView()
            }
        }
        .onStoreDidLoad(self.notesController.$notes, update: self.$hasLoaded)
    }
}
```

## StoredValue Bindings

Both `@StoredValue` and `@SecurelyStoredValue` provide a `.binding` property for two-way SwiftUI bindings.

### Toggle with @StoredValue

```swift
@Observable
final class Preferences {
    @ObservationIgnored
    @StoredValue(key: "hasHapticsEnabled")
    var hasHapticsEnabled = false
}

struct SettingsView: View {
    @State var preferences: Preferences

    var body: some View {
        Form {
            Toggle(
                "Haptics",
                isOn: self.preferences.$hasHapticsEnabled.binding
            )
        }
    }
}
```

### Picker with @StoredValue

```swift
struct ThemePickerView: View {
    @State var preferences: Preferences

    var body: some View {
        Picker("Theme", selection: self.preferences.$currentlySelectedTheme.binding) {
            Text("Light").tag(Theme.light)
            Text("Dark").tag(Theme.dark)
            Text("System").tag(Theme.system)
        }
    }
}
```

### TextField with @SecurelyStoredValue

`@SecurelyStoredValue` bindings are optional (`Binding<Item?>`).

```swift
struct TokenView: View {
    @State var securityManager: SecurityManager

    var body: some View {
        let tokenBinding = Binding(
            get: { self.securityManager.authToken ?? "" },
            set: { try? self.securityManager.$authToken.set($0.isEmpty ? nil : $0) }
        )

        SecureField("Auth Token", text: tokenBinding)
    }
}
```

## Performing Store Operations from Views

Wrap async store operations in `Task` blocks from button actions or gestures.

```swift
struct NoteRow: View {
    let note: Note
    @State var notesController: NotesController

    var body: some View {
        Text(self.note.text)
            .swipeActions(edge: .trailing) {
                Button("Delete", role: .destructive) {
                    Task {
                        try await self.notesController.removeNote(self.note)
                    }
                }
            }
    }
}
```

## Preview Stores

In DEBUG builds, use `Store.previewStore(items:)` to create in-memory stores for SwiftUI previews.

### Identifiable items (String or UUID ID)

```swift
#Preview {
    let store = Store<Note>.previewStore(items: [
        Note(id: "1", text: "First note", createdAt: .now),
        Note(id: "2", text: "Second note", createdAt: .now),
    ])
    let controller = NotesController(store: store)

    NotesListView(notesController: controller)
}
```

### Custom cache identifier

```swift
#Preview {
    let store = Store<Bookmark>.previewStore(
        items: [Bookmark(url: URL(string: "https://example.com")!, title: "Example")],
        cacheIdentifier: \.url.absoluteString
    )
    // ...
}
```

Preview stores only hold items in memory and do not persist to disk. They are only available in DEBUG builds.

## Full Example: Settings Screen

```swift
@Observable
final class AppPreferences {
    @ObservationIgnored
    @StoredValue(key: "hasHapticsEnabled")
    var hasHapticsEnabled = true

    @ObservationIgnored
    @StoredValue(key: "prefersDarkMode")
    var prefersDarkMode = false

    @ObservationIgnored
    @StoredValue(key: "fontSize")
    var fontSize: Double = 16.0
}

struct SettingsView: View {
    @State var preferences: AppPreferences

    var body: some View {
        Form {
            Section("Experience") {
                Toggle("Haptics", isOn: self.preferences.$hasHapticsEnabled.binding)
                Toggle("Dark Mode", isOn: self.preferences.$prefersDarkMode.binding)
            }

            Section("Display") {
                Slider(
                    value: self.preferences.$fontSize.binding,
                    in: 12...24,
                    step: 1
                ) {
                    Text("Font Size: \(Int(self.preferences.fontSize))")
                }
            }
        }
    }
}
```

## Notes

- `@Observable` controllers should be injected as `@State` in SwiftUI views.
- Use `$controller.property` to access the projected value for Boutique operations (`insert`, `remove`, `set`, etc.).
- `onStoreDidLoad` is a View modifier that wraps `store.itemsHaveLoaded()` in a `.task` block.
- Preview stores are `#if DEBUG` only and will not compile in Release builds.
- See `boutique-store` skill for building `@Observable` controllers with `@Stored`.
- See `boutique-stored-values` skill for all `@StoredValue` and `@SecurelyStoredValue` APIs.
