![Bodega Logo](Images/logo.jpg)

### A simple but surprisingly fancy cache

Boutique is a simple but powerful caching library. With it's dual-layered memory + disk caching architecture Boutique provides a way to build apps that update in real-time with full offline storage in only a few lines of code using an incredibly simple API. Boutique is built atop [Bodega](https://github.com/mergesort/Bodega), and you can find a reference implementation in this [repo](https://github.com/mergesort/UMVC) that shows you how to make an offline-ready app in only a few lines of code. You can read more about the philosophy in this blog post exploring a [Unidirectional MVC architecture for SwiftUI](https://fabisevi.ch/fix-this).

### Getting Started

Boutique only has one concept to understand, the `Store`. You may be familiar with the `Store` from [Redux](https://redux.js.org/) or [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture), but unlike those frameworks you won't need to worry about interacting with `Action`s or `Reducer`s. With this `Store` implementation all your data is cached on disk for you automatically, no additional code required. This allows you to build real-time updating apps with full offline support in an incredibly simple and straightforward manner.

---

#### Store

```swift
// Create a Store ¹
let itemsStore = Store<Item>(
    storagePath: Store.documentsDirectory(appendingPathComponent: "Items"),
	cacheIdentifier: \.id
)

// Add an item to the Store ²
let coat = Item(name: "coat")
try await store.add(coat)

// Add two more items to the Store
let purse = Item(name: "purse")
let belt = Item(name: "belt")
try await store.add([purse, belt])

// Remove an item from the Store
try await store.remove(coat)

// You can read items directly
print(self.items) // Prints [coat, belt]

// Since items is an @Published property 
// you can subscribe to any changes in real-time.
store.$items.sink({ items in
	print("Items was updated", items)
})

// In SwiftUI you can even power your Views with $items
// and use .onReceive() to update and manipulate
// data published by the Store's $items.
.onReceive(store.$items, perform: {
   self.allItems = $0.filter({ $0.id > 100 })
})

// Add an item to the store, removing all of the current items 
// from the in-memory and disk cache before saving the new object. ³
try await store.add(coat, invalidationStrategy: .removeAll)

print(self.items) // Prints [coat]

// Clear your store by removing all the items at once.
store.removeAll()

print(self.items) // Prints []

---

¹ You can have as many or as few Stores as you'd like. 
  It may be a good strategy to have one Store for all of the images you download 
  in your app, but you may also want to have one Store per model-type you'd like to cache.
  You can even create separate stores for tests, there is no prescription, 
  the choice for how you'd like to store your data is yours.
  
² Under the hood the Store is doing the work of saving all changes
  to disk when you add or remove objects.

³ There are multiple cache invalidation strategies, `removeAll` would be useful
  when you are downloading completely new data from the server 
  and want to avoid a stale cache.
```

That's it, we've covered the entire surface area of the API. If you can remember `.add()`, `.remove()`, and `.removeAll()`, you now have full offline support in your app, and the ability to integrate real-time changes to your models anywhere in your app, especially useful in SwiftUI.

---

Boutique is very useful on it's own for building real-time offline-ready apps with just a few lines of code, but it's made even more powerful by the Unidirectional MVC architecture I've developed. If you'd like to learn more about how it works you can read about the philosophy in a [blog post](https://fabisevi.ch/fix-this) where I explore UMVC for SwiftUI, and you can find a reference implementation of an offline-ready real-time UMVC app powered by Boutique in this [repo](https://github.com/mergesort/UMVC).

---

### Requirements

- iOS 13.0+
- macOS 11.0
- Xcode 13.2+

### Installation

#### Swift Package Manager

The [Swift Package Manager](https://www.swift.org/package-manager) is a tool for automating the distribution of Swift code and is integrated into the swift compiler.

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
