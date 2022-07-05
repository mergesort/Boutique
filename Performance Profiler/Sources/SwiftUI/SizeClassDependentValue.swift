import SwiftUI

@propertyWrapper
struct SizeClassDependentValue<T>: DynamicProperty {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var regular: T
    var compact: T

    var wrappedValue: T {
        return horizontalSizeClass == .regular && verticalSizeClass == .regular
        ? regular : compact
    }
}

extension EnvironmentValues {
    var isRegularSizeClass: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }

    var isCompactSizeClass: Bool {
        horizontalSizeClass != .regular || verticalSizeClass != .regular
    }
}
