![Boutique Logo](Images/logo.jpg)

### A simple but surprisingly fancy data store and so much more

>*"I ripped out Core Data, this is the way it should work"*

— [Josh Holtz](https://github.com/joshdholtz)

>*"Boutique is ridiculously easy to implement and makes persistence a breeze. It's become my first addition to every project I start.*

— [Tyler Hillsman](https://github.com/thillsman)

>*"Boutique has become invaluable, I use it in every side project now. Not having to care about persistence is great and the cost of getting started is practically zero."*

— [Romain Pouclet](https://github.com/palleas)

If you find Boutique valuable I would really appreciate it if you would consider helping [sponsor my open source work](https://github.com/sponsors/mergesort), so I can continue to work on projects like Boutique to help developers like yourself.

Table of Contents
- [Intro](#intro)
- [Getting Started](#getting-started)
- [Store](#store)
- [The Magic Of @Stored](#the-magic-of-stored)
- [@StoredValue & @SecurelyStoredValue](#storedvalue--securelystoredvalue)
- [Documentation](#documentation)
- [Further Exploration](#further-exploration)
- [Feedback & Contribution](#feedback)

---

### Intro

Boutique is a simple but powerful persistence library, a small set of property wrappers and types that enable building incredibly simple state-driven apps for SwiftUI, UIKit, and AppKit. With its dual-layered memory + disk caching architecture, Boutique provides a way to build apps that update in real time with full offline storage in only a few lines of code — using an incredibly simple API.

- Boutique is used in hundreds of apps, and I thoroughly test every API in my app [Plinky](https://plinky.app). (Which I highly recommend [downloading](https://plinky.app/download) and maybe even subscribing to. 😉)
- Boutique is built atop [Bodega](https://github.com/mergesort/Bodega), and you can find a demo app built atop the Model View Controller Store architecture in this [repo](https://github.com/mergesort/Boutique/tree/main/Demo) which shows you how to make an offline-ready SwiftUI app in only a few lines of code. You can read more about the thinking behind the architecture in this blog post exploring the [MVCS architecture](https://build.ms/2022/06/22/model-view-controller-store).

---

### Getting Started

Boutique only has one concept you need to understand. When you save data to the ``Store`` your data will be persisted automatically for you and exposed as a regular Swift array. The ``@StoredValue`` and ``@SecurelyStoredValue`` property wrappers work the same way, but instead of an array they work with singular Swift values. You'll never have to think about databases, everything in your app is a regular Swift array or value using your app's models, with straightforward code that looks like any other app.

You may be familiar with the ``Store`` from [Redux](https://redux.js.org/) or [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture), but unlike those frameworks you won't need to worry about adding Actions or Reducers. With this ``Store`` implementation all your data is persisted for you automatically, no additional code required. This allows you to build realtime updating apps with full offline support in an incredibly simple and straightforward manner.

You can read a high level overview of Boutique below, but Boutique is also fully documented [here](https://mergesort.github.io/Boutique/documentation/boutique).

---

### Store

We'll go through a high level overview of the `Store` below, but the `Store` is fully documented with context, use cases, and examples [here](https://mergesort.github.io/Boutique/documentation/boutique/using-stores/).

The entire surface area of the API for achieving full offline support and realtime model updates across your entire app is three methods, `.insert()`, `.remove()`, and `.removeAll()`.

```swift
// Create a Store ¹
let store = Store<Animal>(
    storage: SQLiteStorageEngine.default(appendingPath: "Animals"),
    cacheIdentifier: \.id
)

// Insert an item into the Store ²
let redPanda = Animal(id: "red_panda")
try await store.insert(redPanda)

// Remove an animal from the Store
try await store.remove(redPanda)

// Insert two more animals to the Store
let dog = Animal(id: "dog")
let cat = Animal(id: "cat")
try await store.insert([dog, cat])

// You can read items directly
print(store.items) // Prints [dog, cat]

// You also don't have to worry about maintaining uniqueness, the Store handles uniqueness for you
let secondDog = Animal(id: "dog")
try await store.insert(secondDog)
print(store.items) // Prints [dog, cat]

// Clear your store by removing all the items at once.
store.removeAll()

print(store.items) // Prints []

// You can even chain commands together
try await store
    .insert(dog)
    .insert(cat)
    .run()

print(store.items) // Prints [dog, cat]

// This is a good way to clear stale cached data
try await store
    .removeAll()
    .insert(redPanda)
    .run()

print(store.items) // Prints [redPanda]
```

And if you're building a SwiftUI app you don't have to change a thing, Boutique was made for and with SwiftUI in mind. (But works well in UIKit and AppKit of course. 😉)

```swift
// Since @Store, @StoredValue, and @SecurelyStoredValue are `@Observable`, you can subscribe
// to changes in realtime using any of Swift's built-in observability mechanisms.
.onChange(of: store.items) {
    self.items = self.items.sorted(by: { $0.createdAt > $1.createdAt})
})
```

```swift
// You can also use Boutique's Granular Events Tracking API to be notified of individual changes.
func monitorNotesStoreEvents() async {
    for await event in self.notesController.$notes.events {
        switch event.operation {

        case .initialized:
            print("[Store Event: initial] Our Notes Store has initialized")

        case .loaded:
            print("[Store Event: loaded] Our Notes Store has loaded with notes", event.notes.map(\.text))

        case .insert:
            print("[Store Event: insert] Our Notes Store inserted notes", event.notes.map(\.text))

        case .remove:
            print("[Store Event: remove] Our Notes Store removed notes", event.notes.map(\.text))
        }
    }
}
```
---

¹ You can have as many or as few Stores as you'd like. It may be a good strategy to have one Store for all of the notes you download in your app, but you may also want to have one Store per model-type you'd like to cache. You can even create separate stores for tests, Boutique isn't prescriptive and the choice for how you'd like to model your data is yours. You'll also notice, that's a concept from Bodega which you can read about in Bodega's [StorageEngine documentation](https://mergesort.github.io/Bodega/documentation/bodega/using-storageengines).

² Under the hood the Store is doing the work of saving all changes to disk when you add or remove items.

> **Warning** Storing binary blobs (such as images or Data) in Boutique is technically supported, but not recommended. The reason not to store images in Boutique is that storing images in Boutique's can balloon up the in-memory store, and your app's memory as a result. For similar reasons as it's not recommended to store images or binary blobs in a database, it's not recommended to store images or binary blobs in Boutique. Bodega provides a good solution for this problem, which you can read about in [this tutorial](https://mergesort.github.io/Bodega/documentation/bodega/building-an-image-cache/).

---

### The Magic of @Stored

We'll go through a high level overview of the `@Stored` property wrapper below, but `@Stored` is fully documented with context, use cases, and examples [here](https://mergesort.github.io/Boutique/documentation/boutique/the-@stored-family-of-property-wrappers/).


That was easy, but I want to show you something that makes Boutique feel downright magical. The `Store` is a simple way to gain the benefits of offline storage and realtime updates, but by using the `@Stored` property wrapper we can cache any property in-memory and on disk with just one line of code.

```swift
extension Store where Item == Note {
    // Initialize a Store to save our notes into
    static let notesStore = Store<Note>(
        storage: SQLiteStorageEngine.default(appendingPath: "Notes")
    )

}

@Observable
final class NotesController {
    /// Creates an @Stored property to handle an in-memory and on-disk cache of notes. ³
    @Stored(in: .notesStore) var notes

    /// Fetches `Notes` from the API, providing the user with a red panda note if the request succeeds.
    func fetchNotes() async throws -> Note {
        // Hit the API that provides you a random image's metadata
        let noteURL = URL(string: "https://notes.redpanda.club/random/json")!
        let randomNoteRequest = URLRequest(url: noteURL)
        let (noteResponse, _) = try await URLSession.shared.data(for: randomNoteRequest)

        return Note(createdAt: .now, url: noteResponse.url, text: noteResponse.text)
    }

    /// Saves an note to the `Store` in memory and on disk.
    func saveNote(note: Note) async throws {
        try await self.$notes.insert(note)
    }

    /// Removes one note from the `Store` in memory and on disk.
    func removeNote(note: Note) async throws {
        try await self.$notes.remove(note)
    }

    /// Removes all of the notes from the `Store` in memory and on disk.
    func clearAllNotes() async throws {
        try await self.$notes.removeAll()
    }
}
```

That's it, that's really it. This technique scales very well, and sharing this data across many views is exactly how Boutique scales from simple to complex apps without adding API complexity. It's hard to believe that now your app can update its state in real time with full offline storage thanks to only one line of code. `@Stored(in: .notesStore) var notes`

---

³ (If you'd prefer to decouple the store from your view model, controller, or manager object, you can inject stores into the object like this.)

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

### StoredValue & SecurelyStoredValue

We'll go through a high level overview of the `@StoredValue` and `@SecurelyStoredValue` property wrappers below, but they're fully documented with context, use cases, and examples [here](https://mergesort.github.io/Boutique/documentation/boutique/the-@stored-family-of-property-wrappers/).

The `Store` and `@Stored` were created to store an array of data because most data apps render comes in the form of an array. But occasionally we need to store an individual value, that's where `@StoredValue` and `@SecurelyStoredValue` come in handy.

Whether you need to save an important piece of information for the next time your app is launched, stored an auth token in the keychain, or you want to change how an app looks based on a user's settings, those app configurations are individual values that you'll want to persist.

Often times people will choose to store individual items like that in `UserDefaults`. If you've used `@AppStorage` then `@StoredValue` will feel right at home, it has a very similar API with some additional features. A `@StoredValue` will end up being stored in `UserDefaults`, but it also exposes a `publisher` so you can easily subscribe to changes.

```swift
// Setup a `@StoredValue has the same API.
@StoredValue(key: "hasHapticsEnabled")
var hasHapticsEnabled = false

// You can also store nil values
@StoredValue(key: "lastOpenedDate")
var lastOpenedDate: Date? = nil

// Enums work as well, as long as it conforms to `Codable` and `Equatable`.
@StoredValue(key: "currentTheme")
var currentlySelectedTheme = .light

// Complex objects work as well
struct UserPreferences: Codable, Equatable {
    var hasHapticsEnabled: Bool
    var prefersDarkMode: Bool
    var prefersWideScreen: Bool
    var spatialAudioEnabled: Bool
}

@StoredValue(key: "userPreferences")
var preferences = UserPreferences()

// Set the lastOpenedDate to now
$lastOpenedDate.set(.now)

// currentlySelected is now .dark
$currentlySelectedTheme.set(.dark)

// StoredValues that are backed by a boolean also have a toggle() function
$hasHapticsEnabled.toggle()
```

The `@SecurelyStoredValue` property wrapper can do everything a `@StoredValue` does, but instead of storing values in `UserDefaults` a `@SecurelyStoredValue` will persist items in the system's Keychain. This is perfect for storing sensitive values such as passwords or auth tokens, which you would not want to store in `UserDefaults`.

### Documentation

If you have any questions I would ask that you please look at the documentation first, both Boutique and Bodega are very heavily documented. On top of that Boutique comes with not one but two demo apps, each serving a different purpose but demonstrating how you can build a Boutique-backed app.

As I was building v1 I noticed that people who got Boutique loved it, and people who thought it might be good but had questions grew to love it once they understood how to use it. Because of that I sought out to write a lot of documentation explaining the concepts and common use cases you'll encounter when building an iOS or macOS app. If you still have questions or suggestions I'm very open to feedback, how to contribute is discussed in the aptly named [Feedback](#feedback) section of this readme.

- [Boutique Documentation](https://build.ms/boutique/docs)
- [Bodega Documentation](https://build.ms/bodega/docs)
- [Boutique Demo App](https://github.com/mergesort/Boutique/tree/main/Demo)
- [Performance Profiler App](https://github.com/mergesort/Boutique/tree/main/Performance%20Profiler)

---

### Further Exploration

Boutique is very useful on its own for building realtime offline-ready apps with just a few lines of code, but it's even more powerful when you use the Model View Controller Store architecture I've developed, demonstrated in the `NotesController` above. MVCS brings together the familiarity and simplicity of the [MVC architecture](https://developer.apple.com/library/archive/documentation/General/Conceptual/DevPedia-CocoaCore/MVC.html) you know and love with the power of a `Store`, to give your app a simple but well-defined state management and data architecture.

If you'd like to learn more about how it works you can read about the philosophy in a [blog post](https://build.ms/2022/06/22/model-view-controller-store) where I explore MVCS for SwiftUI, and you can find a reference implementation of an offline-ready realtime MVCS app powered by Boutique in this [repo](https://github.com/mergesort/MVCS).

We've only scratched the surface of what Boutique can do here. By leveraging Bodega's `StorageEngine`, you can build complex data pipelines that do everything from caching data to interfacing with your API server. Boutique and Bodega are more than libraries, they're a set of primitives for any data-driven application, so I suggest giving them a shot, playing with the [demo app](https://github.com/mergesort/Boutique/tree/main/Demo), and even building an app of your own!

---

### Feedback & Contribution

This project provides multiple ways to deliver feedback to maintainers.

- If you have a question about Boutique, we ask that you first consult the [documentation](https://build.ms/boutique/docs) to see if your question has been answered there.

- This project is heavily documented but also includes multiple sample projects.
    - The first app is a [Demo app](https://github.com/mergesort/Boutique/tree/main/Demo) which shows you how to build a canonical Boutique app using the Model View Controller Store pattern. The app is heavily documented with inline explanations to help you build an intuition for how a Boutique app works and save you time by teaching you best practices along the way.
    - The second app is a [Performance Profiler](https://github.com/mergesort/Boutique/tree/main/Performance%20Profiler) also using Boutique's preferred architecture. If you're working on a custom `StorageEngine` this project will serve you well as a way to test the performance of the operations you need to build.

- If you still have questions, suggestions for enhancements, or ways to improve Boutique, this project leverages GitHub's [Discussions](https://github.com/mergesort/Boutique/discussions) feature.

- If you find a bug, please report it by creating an issue.

---

### Requirements

- iOS 13.0+
- macOS 11.0+
- Xcode 13.2+

### Installation

#### Swift Package Manager

The [Swift Package Manager](https://www.swift.org/package-manager) is a tool for automating the distribution of Swift code and is integrated into the Swift build system.

Once you have your Swift package set up, adding Boutique as a dependency is as easy as adding it to the dependencies value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/mergesort/Boutique.git", .upToNextMajor(from: "1.0.0"))
]
```

#### Manually

If you prefer not to use SPM, you can integrate Boutique into your project manually by copying the files in.

---

### About me

Hi, I'm [Joe](http://fabisevi.ch) everywhere on the web, but especially on [Bluesky](https://bsky.app/profile/mergesort.me).

### License

See the [license](LICENSE) for more information about how you can use Boutique.

### Sponsorship

Boutique is a labor of love to help developers build better apps, making it easier for you to unlock your creativity and make something amazing for your yourself and your users. If you find Boutique valuable I would really appreciate it if you'd consider helping [sponsor my open source work](https://github.com/sponsors/mergesort), so I can continue to work on projects like Boutique to help developers like yourself.

---

**Now that you know what's *in store* for you, it's time to get started** 🏪
