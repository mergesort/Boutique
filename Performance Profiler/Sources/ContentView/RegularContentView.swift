import Foundation
import SwiftUI

struct RegularContentView: View {
    @State private var notes: [RichNote] = []
    @State private var operation = RichNotesOperation(action: .add)
    @State private var storeLaunchDuration: TimeInterval = 0.0

    private var richNotesController = RichNotesController(store: .notesStore)

    var body: some View {
        HStack {
            VStack(spacing: 0.0) {
                RichNotesOperationsView(operation: self.$operation)

                CountButtonContainerView(
                    operation: self.$operation,
                    addItemsAction: { itemCount in
                        self.failableAsyncOperation({
                            try await richNotesController.addItems(count: itemCount)
                        })
                    },
                    removeItemsAction: { itemCount in
                        self.failableAsyncOperation({
                            try await richNotesController.removeItems(count: itemCount)
                        })
                    },
                    removeAllAction: {
                        self.failableAsyncOperation({
                            try await self.richNotesController.removeAll()
                        })
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .animation(.easeInOut(duration: 0.15), value: self.operation.action)

                Spacer()

                OperationProgressView(operation: self.operation)
            }
            .padding(16.0)
            .frame(width: 360.0)
            .background(Color.palette.appBackground)

            Divider()
                .background(Color.white)

            VStack {
                TerminalView(
                    statistics: [
                        PerformanceStatisticItem(
                            title: "Stored Objects",
                            measurement: "\(notes.count)"
                        ),
                        PerformanceStatisticItem(
                            title: "Used Memory",
                            measurement: "\(MemoryFormatter.formatted(bytes: notes.projectedByteCount))"
                        ),
                        PerformanceStatisticItem(
                            title: "Store Startup Time",
                            measurement: String(format: "%.3f s", self.operation.action == .loading ? 0.0 : self.storeLaunchDuration)
                        ),
                        PerformanceStatisticItem(
                            title: "Avg Object Size",
                            measurement: "\(MemoryFormatter.formatted(bytes: notes.count == 0 ? 0 : notes.projectedByteCount/notes.count, unit: .bytes))"
                        )
                    ]
                )

                Spacer()
            }
            .frame(maxHeight: .infinity)
            .background(Color.palette.appBackground)
            .padding(16.0)
        }
        .background(Color.palette.appBackground)
        .onAppear(perform: {
            self.storeLaunchDuration = ProcessInfo.processInfo.systemUptime
            self.operation.action = .loading
            self.operation.isInProgress = true
        })
        .onChange(of: self.richNotesController.notes, initial: true, {
            self.notes = self.richNotesController.notes
        })
    }
}

private extension RegularContentView {
    func failableAsyncOperation(_ action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
            } catch {
                print("Error running operation", error)
                self.operation.isInProgress = false
            }
        }
    }
}
