import Foundation

internal final class AsyncValueSubject<Value: Sendable>: @unchecked Sendable {
    typealias BufferingPolicy = AsyncStream<Value>.Continuation.BufferingPolicy

    private let lock = NSLock()

    var value: Value
    var bufferingPolicy: BufferingPolicy

    private var continuations: [UInt: AsyncStream<Value>.Continuation] = [:]
    private var count: UInt = 0

    public init(_ initialValue: Value, bufferingPolicy: BufferingPolicy = .unbounded) {
        self.value = initialValue
        self.bufferingPolicy = bufferingPolicy
    }

    // new mutex lock, but iOS 18
    // nslock or dispatchqueue

    func send(_ newValue: Value) {
        // Acquire lock before updating state.
        self.lock.lock()
        self.value = newValue
        // Copy continuations to avoid iterating while holding the lock.
        let currentContinuations = self.continuations
        self.lock.unlock()

        for (_, continuation) in currentContinuations {
            continuation.yield(newValue)
        }
    }

    func `inout`(_ apply: @Sendable (inout Value) -> Void) {
        self.lock.lock()
        apply(&value)
        // Capture current state and continuations.
        let currentValue = value
        let currentContinuations = continuations
        self.lock.unlock()

        for (_, continuation) in currentContinuations {
            continuation.yield(currentValue)
        }
    }

    var values: AsyncStream<Value> {
        AsyncStream(bufferingPolicy: self.bufferingPolicy) { continuation in
            self.insert(continuation)
        }
    }
}

private extension AsyncValueSubject {
    func insert(_ continuation: AsyncStream<Value>.Continuation) {
        self.lock.lock()
        continuation.yield(value)
        let id = count + 1
        count = id
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            guard let self = self else { return }

            Task { self.remove(continuation: id) }
        }
        self.lock.unlock()
    }

    func remove(continuation id: UInt) {
        self.lock.lock()
        continuations.removeValue(forKey: id)
        self.lock.unlock()
    }
}
