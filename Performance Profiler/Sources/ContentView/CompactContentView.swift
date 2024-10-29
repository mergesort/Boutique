import Foundation
import SwiftUI

struct CompactContentView: View {
    @State private var richNotesController = RichNotesController(store: .notesStore)

    @State private var notes: [RichNote] = []
    @State private var operation = RichNotesOperation(action: .add)
    @State private var storeLaunchDuration: TimeInterval = 0.0

    var body: some View {
        VStack(spacing: 0.0) {
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
            .padding(16.0)

            OperationProgressView(operation: self.operation)

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
            .padding(.horizontal, 32.0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.easeInOut(duration: 0.15), value: self.operation.action)

            Text("Selected Operation")
                .fontWeight(.bold)
                .textShadow()
                .font(.telegramaRaw(style: .title1))
                .frame(maxWidth: .infinity)
                .frame(height: 64.0)
                .foregroundColor(.white)

            HStack(alignment: .center, spacing: 16.0) {
                RichNotesOperationsView(operation: self.$operation)
            }
            .padding(16.0)
            .padding(.horizontal, 16.0)

            Spacer()
        }
        .background(Color.palette.appBackground)
        .onAppear(perform: {
            self.storeLaunchDuration = ProcessInfo.processInfo.systemUptime
            self.operation.action = .loading
            self.operation.isInProgress = true
        })
        .onChange(of: self.richNotesController.notes, initial: true, {
            if self.operation.action == .loading {
                self.operation.action = .add
                let initialMarkerTime = self.storeLaunchDuration
                self.storeLaunchDuration = ProcessInfo.processInfo.systemUptime - initialMarkerTime
                self.operation.isInProgress = false
            }

            self.notes = self.richNotesController.notes
        })
    }
}

private extension CompactContentView {
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
