# Using Stores

The ``Store`` is at the heart of what makes Boutique, Boutique.  

## Overview

The ``Store`` is the data storage primitive of a Boutique app, providing two layers of persistence. For every item you save to the ``Store`` there will be an item saved to memory, and that same item will be saved to your `StorageEngine`. The `StorageEngine` is a concept from [Bodega](https://github.com/mergesort/Boutique), representing any data storage mechanism that persists data. If you're looking into a library like Boutique chances are you've used a database, saved files to disk, or stored values in `UserDefaults`, and Boutique aims to streamline that process. If you're using a database like CoreData, Realm, or even CloudKit, you can build a `StorageEngine` tailored to your needs, but Bodega comes with a few built in options you can use. The default suggestion is to use `SQLiteStorageEngine`, a simple and fast way to save data to a database in your app.

Once you setup your ``Store`` you'll never have to think about your persistence layer ever again. Rather than interacting with a database and making queries, you'll always be using Boutique's memory layer. That may sound complex, but all that means is you'll be saving to and reading from an array. Because you're working with a regular array you won't have to make changes to your app to accommodate the ``Store``, everything you've come to expect will work out the box, no changes required.


## Initializing a Store

To start working with a ``Store``, you'll first need to initialize a ``Store`` with a `StorageEngine`

```swift
let store = Store<Item>(
    storage: SQLiteStorageEngine(directory: .defaultStorageDirectory(appendingPath: "Items")),
    cacheIdentifier: \.id
)
```

- The `storage` parameter is populated with a `StorageEngine`, you can read more about it in [Bodega's StorageEngine documentation](https://mergesort.github.io/Bodega/documentation/bodega/using-storageengines). Our SQLite database will be created in the platform's default storage directory, nested in an `Items` subdirectory. On macOS this will be the `Application Support` directory, and on every other platform such as iOS this will be the `Documents` directory. If you need finer control over the location you can specify a `FileManager.Directory` such as `.documents`, `.caches`, `.temporary`, or even provide your own URL, also explored in [Bodega's StorageEngine documentation](https://mergesort.github.io/Bodega/documentation/bodega/using-storageengines).

- The `cacheIdentifier` is a `KeyPath<Model, String>` that your model must provide. That may seem unconventional at first, so let's break it down. Much like how protocols enforce a contract, the KeyPath is doing the same for our model. To be inserted into our ``Store`` and saved to disk our models must conform to `Codable & Equatable`, both of which are reasonable constraints given the data has to be serializable and searchable. But what we're trying to avoid is making our models have to conform to a specialized caching protocol, we want to be able to save any ol' object you already have in your app. Instead of creating a protocol like `Storable`, we instead ask the model to tell us how we can derive a unique string which will be used as a key when storing the item.

If your model (in this case `Item`) already conforms to `Identifiable`, we can simplify our initializer by eschewing the `cacheIdentifier` parameter.

```swift
let store = Store<Item>(
    storage: SQLiteStorageEngine(directory: .defaultStorageDirectory(appendingPath: "Items"))
)
```

And since `SQLiteStorageEngine` is provided to Boutique by Bodega, Bodega exposes a `default(appendingPath:)` initializer we can use.

```swift
static let store = Store<Item>(
    storage: SQLiteStorageEngine.default(appendingPath: "Items")
)
```

This is how simple it is to create a full database-backed persistence layer, only one line of code for something that can take hundreds of lines to implement otherwise.

## How Are Items Stored?

We'll explore how to use `.insert(item: Item)` to save items, but it's worth taking a minute to discuss how items are stored in the ``Store``. When an item is saved to a ``Store``, that item is added to an array of `items`, and it is also persisted by the `StorageEngine`. If we use `DiskStorageEngine` the item will be saved to a disk, or if we use `SQLiteStorageEngine` the item will be saved to a database. The items are saved to the directory specified in the `DiskStorageEngine` or `SQLiteStorageEngine` initializer, and each item will be stored uniquely based on it's `cacheIdentifier` key.

The `cacheIdentifier` provides a mechanism for disambiguating objects, guaranteeing uniqueness of the items in our ``Store``. You never have to think about whether the item needs to be added or inserted (overwriting a matching item), or what index to insert an item at. Since we have a `cacheIdentifier` for every item we will know when an item should be added or overwritten inside of the ``Store``. This behavior means the ``Store`` operates more like a `Set` than an `Array`, because we are inserting items into a bag of objects, and don't care in what order.

As a result the only operations you have to know are `.insert`, `.remove`, and `.removeAll`, all of which are explored in the **Store Operations** section below. If you do need to sort the items into a particular order, for example if you're displaying the items alphabetically, you can always use the `items` property of a ``Store`` and sort, filter, map, or transform it as you would any other array.

To see how this looks I would highly recommend checking out the [Boutique demo app](https://github.com/mergesort/Boutique/tree/main/Demo), as it shows off more complex examples of what Boutique and the Store can do. There's even an example of how to sort items in a View based on time of creation [here](https://github.com/mergesort/Boutique/blob/main/Demo/Demo/Components/FavoritesCarouselView.swift#L152-L154).

## Store Operations

The `items` property of a ``Store`` has an access control of `public private (set)`, preventing the direct modification of the `items` array. If you want to mutate the `items` of a ``Store`` you need to use the three functions the ``Store`` exposes. The API surface area is very small though, there are only three functions you need to know.

Inserts an item into the ``Store``

```swift
let coat = Item(name: "coat")
try await store.insert(coat)
```

Remove an item from the ``Store``

```swift
try await store.remove(coat)
```

Remove all the items a ``Store``

```swift
try await store.removeAll()
```

You can even chain operations using the `.run()` function, executing them in the order they are appended to the ``Store``. This is really useful for situations where you want to clear your ``Store`` before adding new items, such as downloading a fresh set of data from a server.

```swift
try await store
    .removeAll()
    .insert(coat)
    .run()
```


## Sync or Async?

To work with @``Stored`` or alternative property wrappers the ``Store`` must be initialized synchronously. This means that the `items` of your ``Store`` will be loaded in the background, and may not be available immediately. However this can be an issue if you are using the ``Store`` directly and need to show the contents of the ``Store`` immediately, such as on your app's launch'. The ``Store`` provides you with two options to handle a scenario like this.

By using the `async` overload of the ``Store`` initializer your ``Store`` will be returned once all of the `items` are loaded.

```swift
let store: Store<Item>

init() async throws {
    store = try await Store(...)
    // Now the store will have `items` already loaded.
    let items = await store.items
}
```

Alternatively you can use the synchronous initializer, and then await for items to load before accessing them.

```swift
let store: Store<Item> = Store(...)

func getItems() async -> [Item] {
    try await store.itemsHaveLoaded() 
    return await store.items
}
```

The synchronous initializer is a sensible default, but if your app's needs dictate displaying data only once you've loaded all of the necessary items the asynchronous initializers are there to help.

## Further Exploration, @Stored And More

Building an app using the ``Store`` can be really powerful because it leans into SwiftUI's state-driven architecture, while providing you with offline-first capabilities, realtime updates across your app, with almost no additional code required.

We've introduced the ``Store``, but the real power lies when you start to use Boutique's property wrappers, @``Stored``, @``StoredValue``, @``SecurelyStoredValue``, and @``AsyncStoredValue``. These property wrappers help deliver on the promise of working with regular Swift values and arrays yet having data persisted automatically, without ever having to think about the concept of a database.

The next step is to explore how they work, with a small example SwiftUI app. 

- <doc:The-@Stored-Family-Of-Property-Wrappers>

As a reminder you can always play around with the code yourself.

- [A Boutique Demo App](https://github.com/mergesort/Boutique/tree/main/Demo)

Or read through an in-depth technical walkthrough of Boutique, and how it powers the Model View Controller Store architecture.

- [Model View Controller Store: Reinventing MVC for SwiftUI with Boutique](https://build.ms/2022/06/22/model-view-controller-store)
