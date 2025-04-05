# The @Stored Family Of Property Wrappers

Property Wrappers that take the ``Store`` and make it magical. ✨

## Overview

In <doc:Using-Stores> discussed how to initialize a ``Store``, and how to subsequently use it to insert and remove items from that ``Store``. All of the code treats the ``Store`` as an easier to use database, but what if we could remove that layer of abstraction?

The promise of Boutique is that you work with regular Swift values and arrays, yet have your data persisted automatically. The @``Stored``, @``StoredValue``, and @``SecurelyStoredValue`` property wrappers are what help Boutique deliver on that promise.

Using @``Stored`` provides a ``Store`` with array-like ergonomics, while @``StoredValue``, and @``SecurelyStoredValue``, offer similar support for storing single values rather than arrays.

That's a lot of words to discuss how @``Stored`` works under the hood, but seeing some code should make it clearer how to integrate a @``Stored`` array into your app.

## The @Stored Array

Below we have a `NotesController`, a data controller. It has common operations such as the ability to fetch our notes from an API, along with inserting, removing, and clearing them in our app.

```swift
@Observable
final class NotesController {
    @ObservationIgnored
    @Stored var notes: [Note]

    init(store: Store<Note>) {
        self._notes = Stored(in: store)
    }

    func fetchNotesFromAPI() async throws -> [Note] {
        // This would be an API call we make to our server
        try await self.fetchAllNotesFromServer()
 
        // Insert all of the notes we fetched into the local Store once the request succeeds, to keep the state in sync
        try await self.$notes.insert(notes)
    }

    func addNote(note: Note) async throws {
        // This would be an API call we make to our server
        try await self.insertNoteOnServer(note)
 
        // Insert our note into the local Store once the request succeeds, to keep the state in sync
        try await self.$notes.insert(note)
    }

    func removeNote(note: Note) async throws {
        // This would be an API call we make to our server
        try await self.removeRemoteNoteFromServer(note)

        // Remove our note from the local Store once the request succeeds, to keep the state in sync
        try await self.$notes.remove(note)
    }

    func clearAllNotes() async throws {
        // This would be an API call we make to our server
        try await self.removeAllNotesOnServer()

        // Remove all notes from the local Store once the request succeeds, to keep the state in sync
        try await self.$notes.removeAll()
    }
}
```

The functions in our `NotesController` look much like any other Swift object, so what we want to focus in on is the property `@ObservationIgnored @Stored var notes: [Note]`. Let's break that line into three parts, `@ObservationIgnored`, `@Stored` and `var notes`.

The `@ObservationIgnored` attribute tells the Swift Observation system to ignore this property when tracking changes. This is necessary because Swift does not allow having `@Observable` property wrappers within an `@Observable` class. This may seem counterintuitive, but the `@Stored` property wrapper handles observing the changes internally for you, so you will be notified of all changes, just like any other `@Observable` class.

`@Stored` is a property wrapper that's responsible for saving our changes to persisted `Store`, without any extra code necessary. Every time you call `store.insert(item)` or `store.remove(item)`, the `Store` will save changes to it's underlying `StorageEngine` (which makes the data available offline), and updates the variable, in this case `var notes: [Note]`. Using `@Stored` is a handy way to simplify the process of binding a `Store` to the variable that you access in your app.

The last part is `var notes: [Note]`, which should look familiar to any Swift developer. It acts the same as any other array, so any time we reference a `NotesController`'s `notes`, we are accessing a regular array.

What we want to hone in on is @``Stored``, and it's `projectedValue`.

When we use a property wrapper such as @``Stored`` there is a `wrappedValue`, and sometimes there will be a `projectedValue`. In this case the `wrappedValue` is what the property looks like when you are referring to `self.notes`, and the `projectedValue` is what we refer to when we use `self.$notes`. 

We'll use a comparison to show how this works:
```swift
@Stored var notes: [Note]
self.notes // The type of the `wrappedValue` is [Note]
self.$notes // The type of the `projectedValue` is Store<Note>
```

By exposing a ``Store`` as the `projectedValue` we're now able to call `self.$notes.insert(note)` to insert a note into the `notes` array, an array that is read-only from the outside.

Since the ``Store`` is an `@Observable` type, any changes to the `items` array will automatically trigger updates in your SwiftUI views.

```swift
self.notes.insert(note) // Does not work because `notes` is a *read-only* array.
self.$notes.insert(note) // Works because $notes represents a `Store`
```

## Observing Store Changes

#### onChange

With Boutique you can observe changes to a ``Store``'s items using SwiftUI's `.onChange` modifier:

**New:** Previously Boutique 1.x and 2.x we would use `.onReceive` rather than `.onChange`.

```swift
struct NotesListView: View {
    @State var notesController: NotesController
    @State private var notes: [Note] = []

    var body: some View {
        VStack {
            ForEach(self.notes) { note in
                Text(note.text)
                    .onTapGesture {
                        Task {
                            try await notesController.removeNote(note)
                        }
                    }
            }
        }
        .onChange(of: notesController.notes, initial: true) { _, newValue in
            // We can even create complex pipelines, for example filtering all notes smaller than a tweet
            self.notes = newValue.filter { $0.length < 280 }
        }
    }
}
```

In the view above, we're observing changes to `notesController.notes` using the `.onChange` modifier. The `initial: true` parameter ensures that our handler is called when the view first appears, similar to how `onReceive` would behave with it's' initial value.

#### Granular Event Tracking

**New:** You can also observe more granular events using the **Granular Events** API:

```swift
func monitorNotesEvents() async {
    for await event in notesController.$notes.events {
        switch event.operation {
        case .initialized:
            print("Notes Store has initialized")
        case .loaded:
            print("Notes Store has loaded with notes", event.items)
        case .insert:
            print("Notes Store inserted notes", event.items)
        case .remove:
            print("Notes Store removed notes", event.items)
        }
    }
}
```

The Store's `events` property is an `AsyncStream<StoreEvent>`, which tells you two crucial pieces of information for granular observation.

1. You will be told what type of event occured, most commonly `insert` or `remove`. This is also a good way to know when the `Store` was `initialized` or `loaded`, helping differentiate between two events where the result may be an empty array. 
2. You wll be told which items changed. This is different than using `.onChange`, which outputs the new state of a Store's items, based on what items were inserted or removed.

---

Regardless of which approach you choose, there is still only one source of truth (`notesController.notes`). Organizing our app's data this way allows us to have a single source of truth, but each View can render the data it's own way. The reason this works is that the View has it's own local representation of the @``Stored`` array through `@State` (for the root) `@Environment` (for references), pointing back to the same Store. In the View above, we are performing transformations before choosing what to render and how to do it, in this case removing any notes that are too long to fit on Twitter.

Since the `NotesController` has a `removeNote` function we can even handle user interaction such as a user tapping on a note, all within a simple `View`, with an additional benefit of removing the necessity for a ViewModel. 

You may be tempted to remove the extra array, building something that looks like this with `notesController.notes.filter` directly in the `ForEach` loop.

```swift
struct NotesListView: View {
    @State var notesController: NotesController

    var body: some View {
        VStack {
            ForEach(notesController.notes.filter({ $0.length > 280 })) { note in
                Text(note.text)
            }
        }
    }
}
```

This looks simpler, but it's deceptively unperformant. Every time `notesController.notes` is modified, we will have to filter over every note to remove anything longer than a tweet. Each of those operations will trigger SwiftUI to re-render every subview, and while this would be a problem in any SwiftUI app Boutique makes your source of truth easy to access so I wanted to call it out to avoid potential performance pitfalls.

## @StoredValue

The ``Store`` and @``Stored`` were created to store an array of data because most data apps render comes in the form of an array. But occasionally we need to store an individual value, that's where @``StoredValue`` and @``SecurelyStoredValue`` come in handy.

Whether you need to save an important piece of information for the next time your app is launched or if want to change how an app looks based on a user's settings, those app configurations are individual values that you'll want to persist.

Often times people will choose to store individual items like that in `UserDefaults`. If you've used `@AppStorage` then @``StoredValue`` will feel right at home, it has a very similar API with some additional features. A @``StoredValue`` will end up being stored in `UserDefaults`, but it also exposes an `AsyncStream` through the `values` property so you can easily subscribe to changes.

Setting up a @``StoredValue`` is simple. In an `@Observable` class, you'll need to add the `@ObservationIgnored` attribute:

```swift
@Observable
final class Preferences {
    @ObservationIgnored
    @StoredValue(key: "hasHapticsEnabled")
    var hasHapticsEnabled = false
    
    @ObservationIgnored
    @StoredValue(key: "lastOpenedDate")
    var lastOpenedDate: Date? = nil
    
    @ObservationIgnored
    @StoredValue(key: "currentTheme")
    var currentlySelectedTheme = .light
}
```

You can also create a `StoredValue` directly without using a property wrapper, which is useful in non-`@Observable` contexts:

```swift
let hasHapticsEnabled = StoredValue(key: "hasHapticsEnabled", default: false)
```

A more complex example for a hypothetical video player app may look something like this:
```swift
struct UserPreferences: Codable, Sendable, Equatable {
    var hasHapticsEnabled: Bool
    var prefersDarkMode: Bool
    var prefersWideScreen: Bool
    var spatialAudioEnabled: Bool
}

@Observable
final class PreferencesManager {
    @ObservationIgnored
    @StoredValue(key: "userPreferences")
    var preferences = UserPreferences()
}
```

This looks a lot like @`AppStorage`, some minimal API differences aside. Where @``StoredValue`` is different than @`AppStorage` is that it's API more closely resembles working with a ``Store`` than `UserDefaults`.

We'll use the `projectedValue` of our @``StoredValue`` to set a new value. (Accessed by prepending a `$` dollar sign.)

```swift
$lastOpenedDate.set(.now) // Set the lastOpenedDate to now
$currentlySelectedTheme.set(.dark) // currentlySelected is now .dark
```

And we'll use the `projectedValue` of our @``StoredValue`` to reset the values back to their default values.
```swift
$lastOpenedDate.reset() // lastOpenedDate has been reset to it's initial value of nil again
$currentlySelectedTheme.reset() // currentlySelected has been reset to it's initial value of .light
```

One more handy function, if your @``StoredValue`` is a `Bool` you'll also have access to a `.toggle()` function.

```swift
$hasHapticsEnabled.toggle()

// Equivalent to but cleaner than
$hasHapticsEnabled.set(!hasHapticsEnabled)
```

You can also observe changes to a `StoredValue` using the `values` property:

```swift
func monitorThemeChanges() async {
    for await theme in preferences.$currentlySelectedTheme.values {
        print("Theme changed to", theme)
    }
}
```

This separation of concerns makes your code more maintainable and easier to reason about.

## @SecurelyStoredValue

The @``SecurelyStoredValue`` property wrapper automagically persists a single `Item` in the system `Keychain`

The @``SecurelyStoredValue`` property wrapper is very simple, but handles the complicated task of persisting values in the keychain. Traditionally storing values in the keychain requires using arcane C security APIs, but @``SecurelyStoredValue`` makes this task incredibly easy. You should use @``SecurelyStoredValue`` rather than @``StoredValue`` when you need to store sensitive values such as passwords or auth tokens, since a @``StoredValue`` will be persisted in `UserDefaults`. @``SecurelyStoredValue`` is not a full keychain library replacement, instead the property wrapper provides a drop-dead simple alternative for the most common use case.

Creating a @``SecurelyStoredValue`` is very simple. In an `@Observable` class, you'll need to add the `@ObservationIgnored` attribute:

```swift
@Observable
final class SecurityManager {
    @ObservationIgnored
    @SecurelyStoredValue<RedPanda>(key: "redPanda")
    private var redPanda
}
```

Unlike @``StoredValue`` properties @``SecurelyStoredValue`` properties cannot be provided a default value. Since keychain values may or may not exist, a @``SecurelyStoredValue`` is nullable by default. Something to watch out for: You do not need to specify your type as nullable. If you do so the type will be a double optional (`??`) rather than optional (`?`).
```swift
// The type here is not `RedPanda?`, but `RedPanda??`
@SecurelyStoredValue<RedPanda?>(key: "redPanda")
```

Using a @``SecurelyStoredValue`` is the same as a regular @``StoredValue``, the only difference is that the two methods are `set(_:)` and `remove()`, rather than `set(_:)` and `reset()`
```swift
try self.$storedPassword.set("p@ssw0rd") // self.storedPassword is now set to "p@assw0rd" 
try self.$storedPassword.remove() // self.storedPassword is now nil
```

You can also observe changes to a `SecurelyStoredValue` using the `values` property:

```swift
func monitorPasswordChanges() async {
    for await password in securityManager.$storedPassword.values {
        if let password {
            print("Password was set")
        } else {
            print("Password was removed")
        }
    }
}
```

## Breaking Down Objects with Many @StoredValues 

With Boutique support for `@Observable`, you can now break down large objects into smaller, more focused ones while still maintaining reactivity:

```swift
@Observable
final class Preferences {
    var userExperiencePreferences = UserExperiencePreferences()
    var redPandaPreferences = RedPandaPreferences()
}

@MainActor
@Observable
final class UserExperiencePreferences {
    @ObservationIgnored
    @StoredValue(key: "hasSoundEffectsEnabled")
    public var hasSoundEffectsEnabled = false

    @ObservationIgnored
    @StoredValue(key: "hasHapticsEnabled")
    public var hasHapticsEnabled = true
}

@MainActor
@Observable
final class RedPandaPreferences {
    @ObservationIgnored
    @StoredValue(key: "isRedPandaFan")
    public var isRedPandaFan = true
}
```


## Further Exploration

Now that we've covered @``Stored``, @``StoredValue``, and @``SecurelyStoredValue`` we can see how these property wrappers enable your app to work with regular Swift values and arrays, but have your app available offline with realtime state updates easier than ever. There isn't much left to learn about using Boutique, but if you want to explore further you can start using Boutique in one of your apps!

As a reminder you can always play around with the code yourself.

- [A Boutique Demo App](https://github.com/mergesort/Boutique/tree/main/Demo)

Or read through an in-depth technical walkthrough of Boutique, and how it powers the Model View Controller Store architecture.

- [Model View Controller Store: Reinventing MVC for SwiftUI with Boutique](https://build.ms/2022/06/22/model-view-controller-store)
