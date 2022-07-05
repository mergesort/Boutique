import SwiftUI

struct OperationProgressView: View {

    @Binding var operationInProgress: Bool
    @SizeClassDependentValue(regular: UIFont.TextStyle.title3, compact: UIFont.TextStyle.body) private var fontStyle

    var body: some View {
        Text(self.operationInProgress ? "Operation in Progress…" : "Operation Complete")
            .textShadow()
            .padding(16.0)
            .background(Color.palette.terminalBackground)
            .cornerRadius(8.0)
            .foregroundColor(.white)
            .font(.telegramaRaw(style: fontStyle))
    }

}
