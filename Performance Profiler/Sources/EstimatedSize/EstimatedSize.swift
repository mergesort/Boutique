import Foundation

/// A protocol that allows us to gather an object's size by defining the expected size on an extension.
protocol EstimatedSize {
    var projectedByteCount: Int { get }
}
