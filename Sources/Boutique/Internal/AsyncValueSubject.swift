import Foundation

@MainActor
internal final class AsyncValueSubject<Value: Sendable> {
    typealias BufferingPolicy = AsyncStream<Value>.Continuation.BufferingPolicy

    var value: Value
    var bufferingPolicy: BufferingPolicy

    private var continuations: [UInt: AsyncStream<Value>.Continuation] = [:]
    private var count: UInt = 0

    public init(_ initialValue: Value, bufferingPolicy: BufferingPolicy = .unbounded) {
        self.value = initialValue
        self.bufferingPolicy = bufferingPolicy
    }

    func send(_ newValue: Value) {
        self.value = newValue

        for (_, continuation) in continuations {
            continuation.yield(newValue)
        }
    }

    func `inout`(_ apply: @Sendable (inout Value) -> Void) {
        apply(&value)

        for (_, continuation) in self.continuations {
            continuation.yield(value)
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
        continuation.yield(value)
        let id = count + 1
        count = id
        continuations[id] = continuation
        continuation.onTermination = { @Sendable [weak self] _ in
            guard let self else { return }
            Task { await self.remove(continuation: id) }
        }
    }

    func remove(continuation id: UInt) {
        continuations.removeValue(forKey: id)
    }
}
