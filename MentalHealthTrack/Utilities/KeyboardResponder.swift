import SwiftUI
import UIKit

final class KeyboardResponder: ObservableObject {
    @Published var currentHeight: CGFloat = 0

    private var observers: [NSObjectProtocol] = []

    init() {
        let willShow = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                self?.currentHeight = frame.height
            }
        }

        let willHide = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.currentHeight = 0
        }

        observers.append(willShow)
        observers.append(willHide)
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
