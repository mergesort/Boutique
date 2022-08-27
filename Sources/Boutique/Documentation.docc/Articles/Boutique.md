# ``Boutique``

A simple but surprisingly fancy data store and so much more

## Overview

Boutique is a simple but powerful persistence library, and so much more. With Boutique's dual-layered memory + disk caching architecture Boutique provides a way to build SwiftUI, UIKit, and AppKit apps that update in real time with full offline storage in only a few lines of code using an incredibly simple API.

Boutique is built atop [Bodega](https://github.com/mergesort/Bodega), and below is a demo project that demonstrates the ideal Boutique app, along with many useful techniques you can apply to other SwiftUI apps. 

- [Boutique Demo](https://github.com/mergesort/Boutique/tree/main/Demo)

You'll notice that it looks almost identical to any other SwiftUI app, an explicit goal of Boutique. Boutique stays as far away as it can from your app's logic as it can, allowing you to write the app you want to write, with full offline support and realtime state updates that propagate to all of your views in only a few lines of code. You can read more about the thinking behind Boutique and my preference towards a Model View Controller Store architecture in this [blog post](https://build.ms/2022/06/22/model-view-controller-store), but Boutique should work with any architecture.

## Getting Started

Boutique only has one concept you need to understand. When you save data to the ``Store`` your data will be persisted automatically for you and exposed as a regular Swift array. The @``StoredValue`` and @``AsyncStoredValue`` property wrappers work the same way, but instead of an array when you call `$storedValue.set(value)` a singular Swift value will be saved. You'll never have to think about databases, everything in your app is a regular Swift array or value using your app's models, with straightforward code that looks like any other app.

You may be familiar with the ``Store`` from [Redux](https://redux.js.org/) or [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture), but unlike those frameworks you won't need to worry about adding Actions or Reducers. With this ``Store`` implementation all your data is persisted for you automatically, no additional code required. This allows you to build realtime updating apps with full offline support in an incredibly simple and straightforward manner.

If you'd like to explore these core concepts you'll be up and running in no time.

- <doc:Using-Stores>
- <doc:The-@Stored-Family-Of-Property-Wrappers>

Since Boutique is built atop Bodega, learning more about [Bodega](https://github.com/mergesort/Bodega) may be helpful, especially to understand how a ``Store``'s `StorageEngine` works. 

- [Bodega Documentation](https://build.ms/bodega/docs)

## Topics

### Fundamentals

<doc:Using-Stores>
<doc:The-@Stored-Family-Of-Property-Wrappers>
