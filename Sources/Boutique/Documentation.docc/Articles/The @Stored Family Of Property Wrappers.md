# The @Stored Family Of Property Wrappers

Property Wrappers that take the ``Store`` and make it magical. ✨

## Overview

In <doc:Using-Stores> discussed how to initialize a ``Store``, and how to subsequently use it to insert and remove items from that ``Store``. All of the code treats the ``Store`` as an easier to use database, but what if we could remove that layer of abstraction?

The promise of Boutique is that you work with regular Swift values and arrays, yet have your data persisted automatically. The @``Stored``, @``StoredValue``, @``SecurelyStoredValue``, and @``AsyncStoredValue`` property wrappers are what help Boutique deliver on that promise.

Using @``Stored`` provides a ``Store`` with array-like ergonomics, while @``StoredValue``, @``SecurelyStoredValue``, and @``AsyncStoredValue`` offer similar support for storing single values rather than arrays.

That's a lot of words to discuss how @``Stored`` works under the hood, but seeing some code should make it clearer how to integrate a @``Stored`` array into your app.

## The @Stored Array

Below we have a `NotesController`, a data controller. It has common operations such as the ability to fetch our notes from an API, along with inserting, removing, and clearing them in our app.

```swift
final class NotesController: ObservableObject {
    @Stored var notes: [Note]

    init(store: Store<Note>) {
        self._notes = Stored(in: store)
    }

    func fetchNotesFromAPI() -> [Note] {
        // Make an API call that fetches an array of notes from the server... 
        self.$notes.insert(notes)
    }

    func addNote(note: Note) {
        // Make an API call that inserts the note to the server... 
        try await self.$notes.insert(note)
    }

    func removeNote(note: Note) {
        // Make an API call that removes the note from the server... 
        try await self.$notes.remove(note)
    }

    func clearAllNotes() {
        // Make an API call that removes all the notes from the server... 
        self.$notes.removeAll()
    }
}
```

The functions in our `NotesController` look much like any other Swift object, so what we want to focus in on is the property `@Stored var notes: [Note]`. Let's break that line into it's two parts, `@Stored` and `var notes: [Note]`.

The second part should look very familiar, it's the same as every other array we work with in Swift. Any time we want to reference a `NotesController`'s `notes`, it will be just a regular array.

What we want to hone in on is @``Stored``, and it's `projectedValue`.

When we use a property wrapper such as @``Stored`` there is a `wrappedValue`, and sometimes there will be a `projectedValue`. In this case the `wrappedValue` is what the property looks like when you are referring to `self.notes`, and the `projectedValue` is what we refer to when we use `self.$notes`. 

We'll use comparison to show how this works for `@Published`, and what to expect with @``Stored``. 
```swift
@Published var notes: [Note]
self.notes // The type of the `wrappedValue` is [Note]
self.$notes // The type of the `projectedValue` is AnyPublisher<[Note], Never>

@Stored var notes: [Note]
self.notes // The type of the `wrappedValue` is [Note]
self.$notes // The type of the `projectedValue` is Store<Note>
```

By exposing a ``Store`` as the `projectedValue` we're now able to call `self.$notes.insert(note)` to insert a note into the `notes` array, an array that is `@Published public private(set)`.

Since `items` is an `@Published` array that means every time the value is updated, the changes will propagate across our entire app. That's how Boutique achieves it's realtime updating, keeping your entire app in sync without any additional code. 

Making the access control of `items` `public private(set)` makes the `notes` array read-only, letting us observe that array safely in our views. 

```swift
self.notes.insert(note) // Does not work because `notes` is a *read-only* array.
self.$notes.insert(note) // Works because $notes represents a `Store`
```

## Observing a Store's values

The `items` property of a ``Store`` is an array, and as we noted it's a `@Published` array. If you subscribe to `$items` you can use Combine's `sink` operator to observe the values chaning.

```swift
store.$items.sink({ items in
    print("Items was updated", items)
})
```

Even more powerful is seeing how naturally @``Stored`` arrays integrate into SwiftUI. We'll take our `NotesController` and let it be the data source for a SwiftUI view, watching our UI update in real time across all of our views whenever the data changes. While this example is one view, this technique will work in all your views that share the same data source, no matter how complex your views may be.

```swift
struct NotesListView: View {
    @StateObject var notesController: NotesController
    @State private var notes: [Note] = []

    var body: some View {
        VStack {
            ForEach(self.notes) { note in
                Text(note.text)
                    .onTapGesture(perform: {
                        notesController.removeNote(note)
                    }
            }
        }
        .onReceive(notesController.$notes.$items, perform: {
            // We can even create complex pipelines, for example filtering all notes bigger than a tweet
            self.notes = $0.filter({ $0.length > 280 })
        })
    }
}
```

In the view above we're subscribing to the original source of truth in the `onReceive` closure, `notesController.$notes`. Any time `notesController.notes` from anywhere in our app, our `NotesListView` will update as well.

There is still only one source of truth (`notesController.notes`), but each view will have it's own local representation of the @``Stored`` array. This allows us to perform transformations before choosing what to render and how to do it, in this case removing any notes that are too long to fit on Twitter.

Since the `NotesController` has a `removeNote` function we can even handle user interaction such as a user tapping on a note, all within a simple `View`, with an additional benefit of removing the necessity for a ViewModel. 

You may be tempted to remove the extra array, building something that looks like this.

```swift
struct NotesListView: View {
    @StateObject var notesController: NotesController

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

The ``Store`` and @``Stored`` were created to store an array of data because most data apps render comes in the form of an array. But occasionally we need to store an individual value, that's where @``StoredValue``@``SecurelyStoredValue``, and @``AsyncStoredValue`` come in handy.

Whether you need to save an important piece of information for the next time your app is launched or if want to change how an app looks based on a user's settings, those app configurations are individual values that you'll want to persist.

Often times people will choose to store individual items like that in `UserDefaults`. If you've used `@AppStorage` then @``StoredValue`` will feel right at home, it has a very similar API with some additional features. A @``StoredValue`` will end up being stored in `UserDefaults`, but it also exposes a `publisher` so you can easily subscribe to changes.

Setting up a @``StoredValue`` is simple
```swift
@StoredValue(key: "hasHapticsEnabled")
var hasHapticsEnabled = false
```

You can also store nil values
```swift
@StoredValue(key: "lastOpenedDate")
var lastOpenedDate: Date? = nil
```

Or even an enum, as long as it conforms to `Codable` and `Equatable`.
```swift
@StoredValue(key: "currentTheme")
var currentlySelectedTheme = .light
```

A more complex example for a hypothetical video player app may look something like this.
```swift
struct UserPreferences: Codable, Equatable {
    var hasHapticsEnabled: Bool
    var prefersDarkMode: Bool
    var prefersWideScreen: Bool
    var spatialAudioEnabled: Bool
}

@StoredValue(key: "userPreferences")
var preferences = UserPreferences()
```

This looks a lot like @`AppStorage`, some minimal API differences aside. Where @``StoredValue`` is different than @`AppStorage` is that it's API more closely resembles working with a ``Store`` than `UserDefaults`.

We'll use the `projectedValue` of our @``StoredValue`` to set a new value. (Accessed by prepending a `$` dollar sign.)

```swift
$lastOpenedDate.set(.now) // Set the lastOpenedDate to now
$currentlySelectedTheme.set(.dark) // currentlySelected is now .dark
```

And we'll use the `profectedValue` of our @``StoredValue`` to reset the values back to their default values.
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

## @AsyncStoredValue

An @``AsyncStoredValue`` is very similar to ``StoredValue``, the main difference is that rather than storing individual values in `UserDefaults` an ``AsyncStoredValue`` is stored in a `StorageEngine`, much like a ``Store``. This allows you to build your own custom persistence layer for storing values, such as building a `KeychainStorageEngine` to store individual values in the keychain much the same way we can choose our own persistence layer for @``Stored``.

The API for using @``AsyncStoredValue`` is identical to @``StoredValue``, so the @``StoredValue`` examples above will work for @``AsyncStoredValue``. The main difference is that values are received in an async manner, so you have to be prepared to not receive a value immediately or on demand. It may seem strange to have an async alternative to @``StoredValue``, but if you have a `StorageEngine` based upon a remote service such as CloudKit or built atop your app's server API, you'll appreciate the ability to transparently store and persist individual values the same way you would any other data received from your API.

## @SecurelyStoredValue

The @``SecurelyStoredValue`` property wrapper automagically persists a single `Item` in the system `Keychain`

The @``SecurelyStoredValue`` property wrapper is very simple, but handles the complicated task of persisting values in the keychain. Traditionally storing values in the keychain requires using arcane C security APIs, but @``SecurelyStoredValue`` makes this task incredibly easy. You should use @``SecurelyStoredValue`` rather than @``StoredValue`` when you need to store sensitive values such as passwords or auth tokens, since a @``StoredValue`` will be persisted in `UserDefaults`. @``SecurelyStoredValue`` is not a full keychain library replacement, instead the property wrapper provides a drop-dead simple alternative for the most common use case.

Creating a @``SecurelyStoredValue`` is very simple. 
```swift
@SecurelyStoredValue<RedPanda>(key: "redPanda")
private var redPanda
```
Unlike @``StoredValue`` properties @``SecurelyStoredValue`` properties cannot be provided a default value. Since keychain values may or may not exist, a @``SecurelyStoredValue`` is nullable by default. Something to watch out for: You do not need to specify your type as nullable. If you do so the type will be a double optional (`??`) rather than optional (`?`).
```swift
// The type here is not `RedPanda?`, but `RedPanda??`
@SecurelyStoredValue<RedPanda?>(key: "redPanda")
```

Using a @``SecurelyStoredValue`` is the same as a regular @``StoredValue``, the only difference is that the two methods are ``set(_:)`` and ``remove()``, rather than ``set(_:)`` and ``reset()``
```swift
try self.$storedPassword.set("p@ssw0rd") // self.storedPassword is now set to "p@assw0rd" 
try self.$storedPassword.remove() // self.storedPassword is now nil
```

## Further Exploration

Now that we've covered @``Stored``, @``StoredValue``, @``SecurelyStoredValue``, and @``AsyncStoredValue`` we can see how these property wrappers enable your app to work with regular Swift values and arrays, but have your app available offline with realtime state updates easier than ever. There isn't much left to learn about using Boutique, but if you want to explore further you can start using Boutique in one of your apps!

As a reminder you can always play around with the code yourself.

- [A Boutique Demo App](https://github.com/mergesort/Boutique/tree/main/Demo)

Or read through an in-depth technical walkthrough of Boutique, and how it powers the Model View Controller Store architecture.

- [Model View Controller Store: Reinventing MVC for SwiftUI with Boutique](https://build.ms/2022/06/22/model-view-controller-store)
