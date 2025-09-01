import SwiftUI
import UIKit

extension View {
    /// Dismisses the keyboard when tapping anywhere on the view's surface.
    /// Uses a simultaneous tap gesture so it does not block other gestures.
    func hideKeyboardOnTap() -> some View {
        self
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            )
    }
}


