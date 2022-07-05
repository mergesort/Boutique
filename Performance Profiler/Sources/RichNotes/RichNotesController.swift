import Boutique
import SwiftUI

final class RichNotesController: ObservableObject {

    @Stored var notes: [RichNote]

    init(store: Store<RichNote>) {
        self._notes = Stored(in: store)
    }

    func addItems(count: Int) async throws {
        do {
            var items = Array(repeating: RichNote.demoNote, count: count)

            // Adding N items by setting their id to UUIDs to ensure they are unique
            for (index, _) in zip(items.indices, items) {
                items[index].id = UUID().uuidString
            }

            // Profiling how fast the operation is, consider elevating this to the UI
            let timeBeforeAction = Date().timeIntervalSince1970

            try await self.$notes.add(items)

            let timeAfterAction = Date().timeIntervalSince1970
            print(timeBeforeAction, timeAfterAction, String(format: "%.5fs", timeAfterAction - timeBeforeAction))
        } catch {
            print(error)
        }
    }

    func removeItems(count: Int) async throws {
        let removalCount = min(await self.notes.count, count)

        do {
            let firstElements = await Array(self.notes[0..<removalCount])
            try await self.$notes.remove(firstElements)
        } catch {
            print(error)
        }
    }

    func removeAll() async throws {
        try await self.$notes.removeAll()
    }

}
