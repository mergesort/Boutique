import Foundation
import SwiftUI

struct CompactContentView: View {

    @StateObject private var richNotesController = RichNotesController(store: .notesStore)

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

            OperationProgressView(operationInProgress: self.$operation.isInProgress)

            HStack(alignment: .center, spacing: 16.0) {
                RichNotesOperationsView(operation: self.$operation)
            }
            .padding(16.0)
            .padding(.horizontal, 16.0)

            CountButtonContainerView(operation: self.$operation)
                .padding(.horizontal, 32.0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .animation(.easeInOut(duration: 0.15), value: self.operation.action)

            Spacer()
        }
        .background(Color.palette.appBackground)
        .onAppear(perform: {
            self.storeLaunchDuration = ProcessInfo.processInfo.systemUptime
            self.operation.action = .loading
            self.operation.isInProgress = true
        })
        .onReceive(richNotesController.$notes.$items, perform: {
            if self.operation.action == .loading {
                self.operation.action = .add
                let initialMarkerTime = self.storeLaunchDuration
                self.storeLaunchDuration = ProcessInfo.processInfo.systemUptime - initialMarkerTime
                self.operation.isInProgress = false
            }

            self.notes = $0
        })
    }

}

