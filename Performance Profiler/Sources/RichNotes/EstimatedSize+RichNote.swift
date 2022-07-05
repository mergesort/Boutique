import Foundation

extension RichNote: EstimatedSize {

    var projectedByteCount: Int {
        // Threw this in an array cause otherwise it's too large to type-check fast enough, of course...
        return [
            self.id.projectedByteCount,
            self.createdAt.projectedByteCount,
            self.updatedAt.projectedByteCount,
            self.isSynchronized.projectedByteCount,
            self.title.projectedByteCount,
            self.text.projectedByteCount,
            self.attachedURL.projectedByteCount,
            self.tags.projectedByteCount,
            self.annotations.projectedByteCount,
            self.imageAttachment?.projectedByteCount ?? 0,
        ].reduce(0, {
            return $0 + $1
        })
    }

}

extension String: EstimatedSize {
    var projectedByteCount: Int {
        self.utf8.count
    }
}

extension Bool: EstimatedSize {
    var projectedByteCount: Int {
        MemoryLayout<Bool>.size
    }
}

extension Int: EstimatedSize {
    var projectedByteCount: Int {
        MemoryLayout<Int>.size
    }
}

extension Float: EstimatedSize {
    var projectedByteCount: Int {
        MemoryLayout<Float>.size
    }
}

extension URL: EstimatedSize {
    var projectedByteCount: Int {
        MemoryLayout<URL>.size
    }
}

extension Date: EstimatedSize {
    var projectedByteCount: Int {
        MemoryLayout<Double>.size
    }
}

extension Tag: EstimatedSize {
    var projectedByteCount: Int {
        self.title.projectedByteCount +
        self.color.projectedByteCount
    }
}

extension Annotation: EstimatedSize {
    var projectedByteCount: Int {
        self.text.projectedByteCount
    }
}

extension Image: EstimatedSize {
    var projectedByteCount: Int {
        self.url.projectedByteCount +
        self.width.projectedByteCount +
        self.height.projectedByteCount
    }
}

extension Collection where Element: EstimatedSize {
    var projectedByteCount: Int {
        self.reduce(0) {
            return $0 + $1.projectedByteCount
        }
    }
}
