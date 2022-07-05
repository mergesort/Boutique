import Foundation
import SwiftUI

struct RegularContentView: View {

    @StateObject private var richNotesController = RichNotesController(store: .notesStore)

    @State private var notes: [RichNote] = []
    @State private var operation = RichNotesOperation(action: .add)
    @State private var storeLaunchDuration: TimeInterval = 0.0

    var body: some View {
        HStack {
            VStack(spacing: 0.0) {
                RichNotesOperationsView(operation: self.$operation)

                CountButtonContainerView(operation: self.$operation)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .animation(.easeInOut(duration: 0.15), value: self.operation.action)

                Spacer()

                OperationProgressView(operationInProgress: self.$operation.isInProgress)
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

private extension CompactContentView {

    static func formattedMemory(bytes: Int, unit: ByteCountFormatStyle.Units = .mb) -> String {
        ByteCountFormatStyle(style: .memory, allowedUnits: unit).format(Int64(bytes))
    }

}
