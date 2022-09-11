![Boutique Logo](Images/logo.jpg)

### A simple but surprisingly fancy data store and so much more

>*"I ripped out Core Data, this is the way it should work"* 

— [Josh Holtz](https://github.com/joshdholtz)

>*"Boutique is ridiculously easy to implement and makes persistence a breeze. It's become my first addition to every project I start.*

— [Tyler Hillsman](https://github.com/thillsman)

>*"Boutique has become invaluable, I use it in every side project now. Not having to care about persistence is great and the cost of getting started is practically zero."*

— [Romain Pouclet](https://github.com/palleas)

If you find Boutique valuable I would really appreciate it if you would consider helping [sponsor my open source work](https://github.com/sponsors/mergesort), so I can continue to work on projects like Boutique to help developers like yourself.

---

Boutique is a simple but powerful persistence library, a small set of property wrappers and types that enable building incredibly simple state-driven apps for SwiftUI, UIKit, and AppKit. With its dual-layered memory + disk caching architecture Boutique provides a way to build apps that update in real time with full offline storage in only a few lines of code using an incredibly simple API. Boutique is built atop [Bodega](https://github.com/mergesort/Bodega), and you can find a demo app built atop the Model View Controller Store architecture in this [repo](https://github.com/mergesort/MVCS) which shows you how to make an offline-ready SwiftUI app in only a few lines of code. You can read more about the thinking behind the architecture in this blog post exploring the [MVCS architecture](https://build.ms/2022/06/22/model-view-controller-store).

---

* [Getting Started](#getting-started)
* [Store](#store)
* [The Magic Of @Stored](#the-magic-of-stored)
* [@StoredValue & @AsyncStoredValue](#storedvalue--asyncstoredvalue)
* [Documentation](#documentation)
* [Further Exploration](#further-exploration)

---

### Getting Started

Boutique only has one concept you need to understand. When you save data to the ``Store`` your data will be persisted automatically for you and exposed as a regular Swift array. The @``StoredValue`` and @``AsyncStoredValue`` property wrappers work the same way, but instead of an array they work with singular Swift values. You'll never have to think about databases, everything in your app is a regular Swift array or value using your app's models, with straightforward code that looks like any other app.

You may be familiar with the ``Store`` from [Redux](https://redux.js.org/) or [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture), but unlike those frameworks you won't need to worry about adding Actions or Reducers. With this ``Store`` implementation all your data is persisted for you automatically, no additional code required. This allows you to build realtime updating apps with full offline support in an incredibly simple and straightforward manner.

You can read a high level overview of Boutique below, but Boutique is also fully documented [here](https://mergesort.github.io/Boutique/documentation/boutique).

---

### Store

We'll go through a high level overview of the `Store` below, but the `Store` is fully documented with context, use cases, and examples [here](https://mergesort.github.io/Boutique/documentation/boutique/using-stores/).

The entire surface area of the API for achieving full offline support and realtime model updates across your entire app is three methods, `.add()`, `.remove()`, and `.removeAll()`.

```swift
// Create a Store ¹
let store = Store<Animal>(
    storage: SQLiteStorageEngine.default(appendingPath: "Animals"),
    cacheIdentifier: \.id
)

// Add an item to the Store ²
let redPanda = Animal(id: "red_panda")
try await store.add(redPanda)

// Remove an animal from the Store
try await store.remove(redPanda)

// Add two more animals to the Store
let dog = Item(name: "dog")
let cat = Item(name: "cat")
try await store.add([dog, cat])

// You can read items directly
print(store.items) // Prints [dog, cat]

// Clear your store by removing all the items at once.
store.removeAll()

print(store.items) // Prints []

// You can even chain commands together
try await store
    .add(dog)
    .add(cat)
    .run()
    
print(store.items) // Prints [dog, cat]

// This is a good way to clear stale cached data
try await store
    .removeAll()
    .add(redPanda)
    .run()

print(store.items) // Prints [redPanda]
```

And if you're building a SwiftUI app you don't have to change a thing, Boutique was made for and with SwiftUI in mind. (But works well in UIKit and AppKit of course. 😉)

```swift
// Since items is a @Published property 
// you can subscribe to any changes in realtime.
store.$items.sink({ items in
    print("Items was updated", items)
})

// Works great with SwiftUI out the box for more complex pipelines.
.onReceive(store.$items, perform: {
    self.allItems = $0.filter({ $0.id > 100 })
})
```
---

¹ You can have as many or as few Stores as you'd like. It may be a good strategy to have one Store for all of the images you download in your app, but you may also want to have one Store per model-type you'd like to cache. You can even create separate stores for tests, Boutique isn't prescriptive and the choice for how you'd like to model your data is yours. You'll also notice, that's a concept from Bodega which you can read about in Bodega's [StorageEngine documentation](https://mergesort.github.io/Bodega/documentation/bodega/using-storageengines).
  
² Under the hood the Store is doing the work of saving all changes to disk when you add or remove items.

³ In SwiftUI you can even power your `View`s with `$items` and use `.onReceive()` to update and manipulate data published by the Store's `$items`.

> **Warning** Storing images or other binary data in Boutique is technically supported but not recommended. The reason is that storing images in Boutique's can balloon up the in-memory store, and your app's memory as a result. For similar reasons as it's not recommended to store images or binary blobs in a database, it's not recommended to store images or binary blobs in Boutique.

---

### The Magic of @Stored

We'll go through a high level overview of the `@Stored` property wrapper below, but `@Stored` is fully documented with context, use cases, and examples [here](https://mergesort.github.io/Boutique/documentation/boutique/the-@stored-family-of-property-wrappers/).


That was easy, but I want to show you something that makes Boutique feel downright magical. The `Store` is a simple way to gain the benefits of offline storage and realtime updates, but by using the `@Stored` property wrapper we can cache any property in-memory and on disk with just one line of code.

```swift
extension Store where Item == RemoteImage {

    // Initialize a Store to save our images into
    static let imagesStore = Store<RemoteImage>(
        storage: SQLiteStorageEngine.default(appendingPath: "Images")
    )

}

final class ImagesController: ObservableObject {

    /// Creates a @Stored property to handle an in-memory and on-disk cache of images. ⁴
    @Stored(in: .imagesStore) var images

    /// Fetches `RemoteImage` from the API, providing the user with a red panda if the request succeeds.
    func fetchImage() async throws -> RemoteImage {
        // Hit the API that provides you a random image's metadata
        let imageURL = URL(string: "https://image.redpanda.club/random/json")!
        let randomImageRequest = URLRequest(url: imageURL)
        let (imageResponse, _) = try await URLSession.shared.data(for: randomImageRequest)

        return RemoteImage(createdAt: .now, url: imageResponse.url, width: imageResponse.width, height: imageResponse.height, imageData: imageResponse.imageData)
    }
  
    /// Saves an image to the `Store` in memory and on disk.
    func saveImage(image: RemoteImage) async throws {
        try await self.$images.add(image)
    }
  
    /// Removes one image from the `Store` in memory and on disk.
    func removeImage(image: RemoteImage) async throws {
        try await self.$images.remove(image)
    }
  
    /// Removes all of the images from the `Store` in memory and on disk.
    func clearAllImages() async throws {
        try await self.$images.removeAll()
    }

}
```

That's it, that's really it. This technique scales very well, and sharing this data across many views is exactly how Boutique scales from simple to complex apps without adding API complexity. It's hard to believe that now your app can update its state in real time with full offline storage thanks to only one line of code. `@Stored(in: .imagesStore) var images`

---

⁴ (If you'd prefer to decouple the store from your view model, controller, or manager object, you can inject stores into the object like this.)

```swift
final class ImagesController: ObservableObject {

    @Stored var images: [RemoteImage]

    init(store: Store<RemoteImage>) {
        self._images = Stored(in: store)
    }

}
```

### StoredValue & AsyncStoredValue

We'll go through a high level overview of the `@StoredValue` and `@AsyncStoredValue` property wrappers below, but they're fully documented with context, use cases, and examples [here](https://mergesort.github.io/Boutique/documentation/boutique/the-@stored-family-of-property-wrappers/).

The `Store` and `@Stored` were created to store an array of data because most data apps render comes in the form of an array. But occasionally we need to store an individual value, that's where @`StoredValue` and @`AsyncStoredValue` come in handy.

Whether you need to save an important piece of information for the next time your app is launched or if want to change how an app looks based on a user's settings, those app configurations are individual values that you'll want to persist.

Often times people will choose to store individual items like that in `UserDefaults`. If you've used `@AppStorage` then @`StoredValue` will feel right at home, it has a very similar API with some additional features. A @`StoredValue` will end up being stored in `UserDefaults`, but it also exposes a `publisher` so you can easily subscribe to changes.

```swift
// Setup a `@StoredValue, @AsyncStoredValue has the same API.
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

An @``AsyncStoredValue`` is very similar to @``StoredValue``, the main difference is that rather than storing individual values in `UserDefaults` an @``AsyncStoredValue`` is stored in a `StorageEngine`, much like a ``Store``. This allows you to build your own custom persistence layer for storing values, such as building a `KeychainStorageEngine` to store individual values in the keychain much the same way we can choose our own persistence layer for @``Stored``.

### Documentation

If you have any questions I would ask that you please look at the documentation first, both Boutique and Bodega are very heavily documented. On top of that Boutique comes with not one but two demo apps, each serving a different purpose but demonstrating how you can build a Boutique-backed app.

As I was building v1 I noticed that people who got Boutique loved it, and people who thought it might be good but had questions grew to love it once they understood how to use it. Because of that I sought out to write a lot of documentation explaining the concepts and common use cases you'll encouter when building an iOS or macOS app. If you still have questions or suggestions I'm very open to feedback, how to contribute is discussed in the aptly named [Feedback](#feedback) section of this readme.

- [Boutique Documentation](https://build.ms/boutique/docs)
- [Bodega Documentation](https://build.ms/bodega/docs)
- [Boutique Demo App](https://github.com/mergesort/Boutique/tree/main/Demo)
- [Performance Profiler App](https://github.com/mergesort/Boutique/tree/main/Performance%20Profiler)

---

### Further Exploration

Boutique is very useful on its own for building realtime offline-ready apps with just a few lines of code, but it's even more powerful when you use the Model View Controller Store architecture I've developed, demonstrated in the `ImagesController` above. MVCS brings together the familiarity and simplicity of the [MVC architecture](https://developer.apple.com/library/archive/documentation/General/Conceptual/DevPedia-CocoaCore/MVC.html) you know and love with the power of a `Store`, to give your app a simple but well-defined state management and data architecture.

If you'd like to learn more about how it works you can read about the philosophy in a [blog post](https://build.ms/2022/06/22/model-view-controller-store) where I explore MVCS for SwiftUI, and you can find a reference implementation of an offline-ready realtime MVCS app powered by Boutique in this [repo](https://github.com/mergesort/MVCS).

We've only scratched the surface of what Boutique can do here. Leveraging Bodega's `StorageEngine` you can build complex data pipelines that do everything from caching data to interfacing with your API server. Boutique and Bodega are more than libraries, they're a set of primitives for any data-driven application, so I suggest giving them a shot, playing with the [demo app](https://github.com/mergesort/Boutique/tree/main/Demo), and even building an app of your own!

---

### Feedback

This project provides multiple forms of delivering feedback to maintainers.

- If you have a question about Boutique, we ask that you first consult the [documentation](https://build.ms/boutique/docs) to see if your question has been answered there.

- This project is heavily documented but also includes multiple sample projects.
    - The first app is a [Demo app](https://github.com/mergesort/Boutique/tree/main/Demo) which shows you how to build a canonical Boutique app using the Model View Controller Store pattern. The app is heavily documented with inline explanations to help you build an intuition for how a Boutique app works and save you time by teaching you best practices along the way.
    - The second app is a [Performance Profiler](https://github.com/mergesort/Boutique/tree/main/Performance%20Profiler) also using Boutique's preferred architecture. If you're working on a custom `StorageEngine` this project will serve you well as a way to test the performance of the operations you need to build.

- If you still have a question, enhancement, or a way to improve Boutique, this project leverages GitHub's [Discussions](https://github.com/mergesort/Boutique/discussions) feature.

- If you find a bug and wish to report an [issue](https://github.com/mergesort/Boutique/issues) would be appreciated.

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

Hi, I'm [Joe](http://fabisevi.ch) everywhere on the web, but especially on [Twitter](https://twitter.com/mergesort).

### License

See the [license](LICENSE) for more information about how you can use Boutique.

### Sponsorship

Boutique is a labor of love to help developers build better apps, making it easier for you to unlock your creativity and make something amazing for your yourself and your users. If you find Boutique valuable I would really appreciate it if you'd consider helping [sponsor my open source work](https://github.com/sponsors/mergesort), so I can continue to work on projects like Boutique to help developers like yourself.

---

**Now that you know what's *in store* for you, it's time to get started.** 🏪
