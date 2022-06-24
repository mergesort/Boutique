# ``Boutique``

A batteries-included app persistence layer, called `Store`, that comes with everything you'll need out of the box. 

## Overview

Boutique's Store is a dual-layered memory and disk cache which lets you build apps that update in real time with full offline storage and an incredibly simple API in only a few lines of code. It fits really well with SwiftUI apps that need a single source of truth data model to drive the UI. 

Boutique is powered under the hood by `Bodega`, an actor-based library for saving data and `Codable` objects to disk.

For more details on the library motivation and design details, read [Model View Controller Store: Reinventing MVC for SwiftUI with Boutique](https://build.ms/2022/06/22/model-view-controller-store/).

## Topics

### Essentials

- <doc:Example>

### Data Storage

- ``Store``
- ``Stored``
