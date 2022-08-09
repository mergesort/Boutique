# Boutique: A Simple, Familiar, Yet Powerful Approach To Building SwiftUI, UIKit, and AppKit Apps

<p align="center">
  <img 
  src="Images/Demo-App.png"
  >
</p>

Welcome to a demo of building an app with Boutique. This repo is primarily oriented to sharing the Boutique demo code. If you'd like to learn more about how Model View Controller Store, Boutique, and Bodega work, please read the walkthrough [in this post](https://build.ms/2022/06/22/model-view-controller-store/) or reference [Boutique's documentation](https://build.ms/boutique/docs).

The best way to explain Boutique and Model View Controller Store is to show you what it is. The idea is so small that I'm convinced you can look at the code in this repo and know how it works almost immediately, there's actually very little to learn. Boutique is a library I've developed to provide a batteries-included `Store`, and doesn't require you to change your apps to use it.

Boutique requires no tricks to use, does *no behind the scenes magic*, and doesn't resort to shenanigans like runtime hacking to achieve a great developer experience. Boutique's `Store` is a dual-layered memory and disk cache which ***lets you build apps that update in real time with full offline storage with three lines of code and an incredibly simple API***. That may sound a bit fancy but all it means is that when you save an object into the `Store`, it also saves that object to a database. This persistence is powered under the hood by [Bodega](https://github.com/mergesort/Bodega), an actor-based library I've developed for building data storage engines.

If you think this sounds too good to be true I recommend you play with the app yourself and see how simple it really is.

<h3 align="center">
  Plus don't you want to look at some cute red pandas?
</h3>

https://user-images.githubusercontent.com/716513/174133310-239d7da7-8a0d-48e6-a909-c9a121078f74.mov

> **Note**
> While this demo app stores images in Boutique, storing images or other binary data in Boutique is not recommended. The reason for this is that storing images in Boutique can balloon up your app's memory, so the same way you wouldn't put images into a database you should avoid storing images in Boutique.
> 
>  This was something I only considered after releasing Boutique, and this demo project is still great for demonstrating what Boutique can do, but if you're storing images wouldn't scale to storing the thousands of objects Boutique can handle otherwise. I'm working on an example wtihout images to make sure it's clearer to not use Boutique as an image cache, but I ask folks be patient as I've been overwhelmed with tons of [really positive] feedback. With that said, [Bodega](https://github.com/mergesort/Bodega) is a great way to store binary data to disk, and I would highly recommend it for downloading and storing images.
