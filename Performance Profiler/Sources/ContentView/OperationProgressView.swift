import SwiftUI

struct OperationProgressView: View {
    var operation: RichNotesOperation

    @SizeClassDependentValue(regular: UIFont.TextStyle.title3, compact: UIFont.TextStyle.body) private var fontStyle

    var body: some View {
        Text(self.title)
            .textShadow()
            .padding(16.0)
            .background(Color.palette.terminalBackground)
            .cornerRadius(8.0)
            .foregroundColor(.white)
            .font(.telegramaRaw(style: fontStyle))
    }
}

private extension OperationProgressView {
    var title: String {
        switch self.operation.action {
        case .add: "Insert"
        case .remove: "Remove"
        case .loading: "Operation in Progress…"
        case .none: "Operation Complete"
        }
    }
}
