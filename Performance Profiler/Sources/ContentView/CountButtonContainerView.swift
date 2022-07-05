import SwiftUI

struct CountButtonContainerView: View {

    @StateObject private var richNotesController = RichNotesController(store: .notesStore)
    @Binding var operation: RichNotesOperation

    @SizeClassDependentValue(regular: 16.0, compact: 8.0) private var stackSpacing
    @SizeClassDependentValue(regular: Edge.leading, compact: Edge.trailing) private var animatedEdge

    var body: some View {
        VStack(spacing: stackSpacing) {
            let buttonColor = self.operation.action == .add ? Color.palette.add : Color.palette.remove

            Self.countButton("1 OBJECT", color: buttonColor, action: {
                try await self.tappedCountButton(count: 1)
            })

            Self.countButton("10 OBJECTS", color: buttonColor, action: {
                try await self.tappedCountButton(count: 10)
            })

            Self.countButton("100 OBJECTS", color: buttonColor, action: {
                try await self.tappedCountButton(count: 100)
            })

            Self.countButton("1000 OBJECTS", color: buttonColor, action: {
                try await self.tappedCountButton(count: 1000)
            })

            if self.operation.action == .remove {
                Self.countButton("All OBJECTS", color: buttonColor, action: {
                    try await self.richNotesController.removeAll()
                })
                .transition(.move(edge: animatedEdge))
            }
        }

    }

    func tappedCountButton(count: Int) async throws {
        self.operation.isInProgress = true

        // Since this is just a profiler app I'm too to figure out why we need a delay
        // to make the progress state change show up correctly when adding a large amount of items
        try await Task.sleep(nanoseconds: 10_000_000)

        do {
            if self.operation.action == .add {
                try await richNotesController.addItems(count: count)
            } else {
                try await richNotesController.removeItems(count: count)
            }
        } catch {
            print("Error running operation", error)
            self.operation.isInProgress = false
        }

        self.operation.isInProgress = false
    }

}

private extension CountButtonContainerView {

    static func countButton(_ title: String, color: Color, action: @escaping () async throws -> Void) -> some View {
        Button(action: {
            Task {
                try await action()
            }
        }, label: {
            Text(title)
                .font(.telegramaRaw(style: .title1))
                .buttonStyle(.borderedProminent)
                .foregroundColor(.white)
                .textShadow()
        })
        .frame(height: 52.0)
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 8.0)
                .stroke(color, lineWidth: 2.0)
        )
    }

}
