![Boutique Logo](Images/logo.jpg)

### A simple but surprisingly fancy Store

Boutique is a simple but powerful persistence library, and more. With its dual-layered memory + disk caching architecture Boutique provides a way to build apps that update in real time with full offline storage in only a few lines of code using an incredibly simple API. Boutique is built atop [Bodega](https://github.com/mergesort/Bodega), and you can find a reference implementation of an app built atop the Model View Controller Store architecture in this [repo](https://github.com/mergesort/MVCS) which shows you how to make an offline-ready SwiftUI app in only a few lines of code. You can read more about the thinking behind the architecture in this blog post exploring the [MVCS architecture](https://build.ms/2022/06/22/model-view-controller-store).

---

* [Getting Started](#getting-started)
* [Store](#store)
* [The Magic Of @Stored](#the-magic-of-stored)
* [Further Exploration](#further-exploration)

---

### Getting Started

Boutique only has one concept to understand, the `Store`. You may be familiar with the `Store` from [Redux](https://redux.js.org/) or [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture), but unlike those frameworks you won't need to worry about interacting with `Action`s or `Reducer`s. With this `Store` implementation all your data is cached on disk for you automatically, no additional code required. This allows you to build realtime updating apps with full offline support in an incredibly simple and straightforward manner.

---

### Store

The entire surface area of the API for achieving full offline support and realtime model updates across your entire app is three methods, `.add()`, `.remove()`, and `.removeAll()`.

```swift
// Create a Store ¹
let itemsStore = Store<Item>(
    storagePath: Store.documentsDirectory(appendingPathComponent: "Items"),
    cacheIdentifier: \.id
)

// Add an item to the Store ²
let coat = Item(name: "coat")
try await store.add(coat)

// Remove an item from the Store
try await store.remove(coat)

// Add two more items to the Store
let purse = Item(name: "purse")
let belt = Item(name: "belt")
try await store.add([purse, belt])

// You can read items directly
print(self.items) // Prints [coat, belt]

// Clear your store by removing all the items at once.
store.removeAll()

print(self.items) // Prints []

// Add an item to the store, removing all of the current items 
// from the in-memory and disk cache before saving the new object. ³
try await store.add([purse, belt], invalidationStrategy: .removeNone)
try await store.add(coat, invalidationStrategy: .removeAll)

print(self.items) // Prints [coat]
```

And if you're building a SwiftUI app you don't have to change a thing, Boutique was made for and with SwiftUI in mind.

```swift
// Since items is an @Published property 
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

¹ You can have as many or as few Stores as you'd like. It may be a good strategy to have one Store for all of the images you download in your app, but you may also want to have one Store per model-type you'd like to cache. You can even create separate stores for tests, Boutique isn't prescriptive and the choice for how you'd like to model your data is yours.
  
² Under the hood the Store is doing the work of saving all changes to disk when you add or remove objects.

³ There are multiple cache invalidation strategies. `removeAll` would be useful when you are downloading completely new data from the server and want to avoid a stale cache.

⁴ In SwiftUI you can even power your `View`s with `$items` and use `.onReceive()` to update and manipulate data published by the Store's `$items`.

---

### The Magic of @Stored

That was easy, but I want to show you something that makes Boutique feel downright magical. The `Store` is a simple way to gain the benefits of offline storage and realtime updates, but by using the `@Stored` property wrapper we can cache any property in-memory and on disk with just one line of code.

```swift
final class ImagesController: ObservableObject {

    /// Creates an @Stored property to handle an in-memory and on-disk cache of images. ⁵
    @Stored(in: Store.imagesStore) var images

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

That's it, that's really it. It's hard to believe that now your app can update its state in real time with full offline storage thanks to only one line of code. `@Stored(in: Store.imagesStore) var images`

---

⁵ (If you'd prefer to decouple the store from your view model, controller, or manager object, you can inject stores into the object like this.)

```swift
final class ImagesController: ObservableObject {

    @Stored var images: [RemoteImage]

    init(store: Store<RemoteImage>) {
        self._images = Stored(in: store)
    }

}
```

---

### Further Exploration

Boutique is very useful on its own for building realtime offline-ready apps with just a few lines of code, but it's made even more powerful by the Model View Controller Store architecture I've developed, demonstrated in the `ImagesController` above. MVCS brings together the familiarity and simplicity of the [MVC architecture](https://developer.apple.com/library/archive/documentation/General/Conceptual/DevPedia-CocoaCore/MVC.html) you know and love with the power of a `Store`, to give your app a simple but well-defined state management and data architecture.

If you'd like to learn more about how it works you can read about the philosophy in a [blog post](https://build.ms/2022/06/22/model-view-controller-store) where I explore MVCS for SwiftUI, and you can find a reference implementation of an offline-ready realtime MVCS app powered by Boutique in this [repo](https://github.com/mergesort/MVCS).

---

### Requirements

- iOS 13.0+
- macOS 11.0+
- Xcode 13.2+

### Installation

#### Swift Package Manager

The [Swift Package Manager](https://www.swift.org/package-manager) is a tool for automating the distribution of Swift code and is integrated into the Swift build system.

Once you have your Swift package set up, adding Bodega as a dependency is as easy as adding it to the dependencies value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/mergesort/Boutique.git", .upToNextMajor(from: "1.0.0"))
]
```

#### Manually

If you prefer not to use SPM, you can integrate Bodega into your project manually by copying the files in.

---

## About me

Hi, I'm [Joe](http://fabisevi.ch) everywhere on the web, but especially on [Twitter](https://twitter.com/mergesort).

## License

See the [license](LICENSE) for more information about how you can use Bodega.
