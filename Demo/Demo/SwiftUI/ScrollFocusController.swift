import Combine
import SwiftUI

/// A controller that allows a parent to subscribe to a child's tap events for the purpose of scrolling.
final class ScrollFocusController<T: Hashable>: ObservableObject {
    private let currentValueSubject = CurrentValueSubject<T?, Never>(nil)

    var publisher: AnyPublisher<T?, Never> {
        return self.currentValueSubject.eraseToAnyPublisher()
    }

    func scrollTo(_ remoteImage: T) {
        self.currentValueSubject.value = remoteImage
        self.currentValueSubject.value = nil
    }
}
