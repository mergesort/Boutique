import Observation

/// The @``Stored`` property wrapper to automagically initialize a ``Store``.
@MainActor
///
/// When using `@Stored` in an `@Observable` class, you should add the `@ObservationIgnored` attribute
/// to prevent duplicate observation tracking:
///
/// ```swift
/// @Observable
/// final class NotesController {
///     @ObservationIgnored
///     @Stored var notes: [Note]
///
///     init(store: Store<Note>) {
///         self._notes = Stored(in: store)
///     }
///
///     func addNote(note: Note) async throws {
///         try await self.$notes.insert(note)
///     }
/// }
/// ```
///
/// You can observe changes to the stored items using SwiftUI's `.onChange` modifier:
///
/// ```swift
/// .onChange(of: notesController.notes, initial: true) { _, newValue in
///     self.filteredNotes = newValue.filter { $0.isImportant }
/// }
/// ```
@propertyWrapper
public struct Stored<Item: StorableItem> {
    private let store: Store<Item>

    /// Initializes a @``Stored`` property that will be exposed as an `[Item]` and project a `Store<Item>`.
    /// - Parameter store: The store that will be wrapped to expose as an array.
    public init(in store: Store<Item>) {
        self.store = store
    }

    /// The currently stored items
    public var wrappedValue: [Item] {
        self.store.items
    }

    public var projectedValue: Store<Item> {
        self.store
    }
}
