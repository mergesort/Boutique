import Foundation

internal final class AsyncValueSubject<Value: Sendable>: @unchecked Sendable {
    typealias BufferingPolicy = AsyncStream<Value>.Continuation.BufferingPolicy

    private let lock = NSLock()

    private var storedValue: Value
    var bufferingPolicy: BufferingPolicy

    private var continuations: [UInt: AsyncStream<Value>.Continuation] = [:]
    private var count: UInt = 0

    public init(_ initialValue: Value, bufferingPolicy: BufferingPolicy = .unbounded) {
        self.storedValue = initialValue
        self.bufferingPolicy = bufferingPolicy
    }

    func send(_ newValue: Value) {
        // Acquire lock before updating state.
        self.lock.lock()
        self.storedValue = newValue
        // Copy continuations to avoid iterating while holding the lock.
        let currentContinuations = self.continuations
        self.lock.unlock()

        for (_, continuation) in currentContinuations {
            continuation.yield(newValue)
        }
    }

    var value: Value {
        get {
            self.lock.lock()
            defer { self.lock.unlock() }

            return self.storedValue
        }
        set {
            self.lock.lock()
            self.storedValue = newValue
            self.lock.unlock()
        }
    }

    func `inout`(_ apply: @Sendable (inout Value) -> Void) {
        self.lock.lock()
        apply(&storedValue)
        // Capture current state and continuations.
        let currentValue = storedValue
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
        continuation.yield(storedValue)
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
