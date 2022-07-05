import SwiftUI

struct RichNotesOperation {

    var isInProgress: Bool = false
    var action: Action?

    enum Action {
        case add
        case remove
        case loading
    }

}

struct RichNotesOperationsView: View {

    @Binding var operation: RichNotesOperation
    @Environment(\.isRegularSizeClass) private var isRegularSizeClass

    var body: some View {
        SizingResistantView {
            Button(action: {
                self.operation.action = .add
            }, label: {
                Text("Add")
                    .fontWeight(.bold)
                    .textShadow()
                    .font(.telegramaRaw(style: .title1))
                    .frame(maxWidth: .infinity)
                    .frame(height: 64.0)
                    .foregroundColor(.white)
            })
        }
        .frame(maxWidth: .infinity)
        .background(self.operation.action == .add ? Color.palette.add : .gray)
        .clipShape(RoundedRectangle(cornerRadius: 16.0))
        .ghostEffectShadow(self.operation.action == .add ? Color.palette.add : .gray)

        if isRegularSizeClass {
            Spacer().frame(height: 16.0)
        }

        SizingResistantView {
            Button(action: {
                self.operation.action = .remove
            }, label: {
                Text("Remove")
                    .font(.telegramaRaw(style: .title1))
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64.0)
                    .foregroundColor(.white)
                    .textShadow()
            })
            .frame(maxWidth: .infinity)
            .background(self.operation.action == .remove ? Color.palette.remove : .gray)
            .clipShape(RoundedRectangle(cornerRadius: 16.0))
            .ghostEffectShadow(self.operation.action == .remove ? Color.palette.remove : .gray)
        }

        if isRegularSizeClass {
            Spacer().frame(height: 16.0)
        }
    }
}
