# Building a simple SwiftUI app with Boutique

Build an offline-capable SwiftUI app with Boutique in just few steps.

## Overview

Persist `Codable` data models and drive your SwiftUI app with Boutique.

### Define data models

Define your model types as usual for a SwiftUI app. Conform to `Identifiable` to make it easier to unqiuely reference models:

```swift
struct RemoteImage: Codable, Equatable, Identifiable {
  let url: URL
  let dataRepresentation: Data

  var id: String {
    url.absoluteString
  }
}
```

### Create a data store for your type(s)

Define a default store for a given data type. Add an extension on ``Store`` when the stored data type is your model and define the location on disk to persist the objects: 

```swift
extension Store where Item == RemoteImage {
  static let imagesStore = Store<RemoteImage>(
    storagePath: Store.documentsDirectory(appendingPath: "Images")
  )
}
```

### Drive the app's UI from your data store

Finally, bind the store to drive your app's UI:

```swift
struct ContentView: View {
  @Stored(in: .imagesStore) var images

  var body: some View {
    List(images, id: \.id) { image in
      Image(uiImage: .init(data: image.dataRepresentation)!)
    }
  }
}
```

If you want to perform sorting, filtering, or otherwise process the stored objects before binding them to your UI, add the store to a controller (`ObservedObject`) to do that and bind the UI to its published properties.

## See Also

This article is an abbreviated version of the content in the Boutique announcement blog post and its accompanying example app:

 - [Model View Controller Store](https://build.ms/2022/06/22/model-view-controller-store)
 - [MVCS: A Simple, Familiar, Yet Powerful Architecture for building SwiftUI Apps](https://github.com/mergesort/MVCS)
