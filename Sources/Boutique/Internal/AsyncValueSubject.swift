import Foundation

internal final class AsyncValueSubject<T: Sendable> {
    private var value: T
    private var continuations: [AsyncStream<T>.Continuation] = []

    init(_ value: T) {
        self.value = value
    }

    var values: AsyncStream<T> {
        AsyncStream { continuation in
            continuations.append(continuation)
            continuation.yield(value)
        }
    }

    func send(_ newValue: T) {
        value = newValue
        for continuation in continuations {
            continuation.yield(newValue)
        }
    }
}
