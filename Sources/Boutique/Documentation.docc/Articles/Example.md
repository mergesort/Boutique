# Building a simple SwiftUI app with Boutique

Build an offline-capable SwiftUI app with Boutique in just few steps.

## Overview

Persist `Codable` data models and drive your SwiftUI app with Boutique.

### Define data models

Define your model types as usual for a SwiftUI app. Conforming to `Identifiable` is not required but makes it easier to generate a unique identifier for your model:

```swift
struct RemoteImage: Codable, Equatable, Identifiable {
  let url: URL
  let width: Float
  let height: Float

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
        AsyncImage(url: image.url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            ProgressView()
                .progressViewStyle(.circular)
        }
        .frame(width: 240.0, height: 240.0)
    }
  }
}
```

If you want to perform sorting, filtering, or otherwise process the stored objects before binding them to your UI, add the store to a controller (`ObservedObject`) to do that and bind the UI to its published properties.

## See Also

This article is an abbreviated version of the content in the Boutique announcement blog post and its accompanying example app:

 - [Model View Controller Store](https://build.ms/2022/06/22/model-view-controller-store)
 - [MVCS: A Simple, Familiar, Yet Powerful Architecture for building SwiftUI Apps](https://github.com/mergesort/MVCS)
