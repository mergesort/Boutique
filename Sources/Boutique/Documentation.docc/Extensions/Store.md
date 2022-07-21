# ``Boutique/Store``

## Creating and using a store

You define and initialize a store in just few lines. 

Once you've configured a store for a certain data type you can use it in your controllers or views as:

```swift
@Stored(in: .imagesStore) var images
```

`images` above is then a collection of the stored type so you can loop over it, bind it, and filter is usual.

For a more detailed code example refer to <doc:Example>.

## Topics

### Initialization

 - ``init(storagePath:)``
 - ``init(storagePath:cacheIdentifier:)``

### Content

 - ``items``

### Updating the store

 - ``add(_:invalidationStrategy:)-5y90k``
 - ``add(_:invalidationStrategy:)-4mi2i``

 - ``remove(_:)-5dwyv``
 - ``remove(_:)-3nzlq``
 - ``removeAll()``

### Invalidation

 - ``ItemRemovalStrategy``
