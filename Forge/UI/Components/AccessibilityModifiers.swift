import SwiftUI

/// Convenience modifier for action buttons that have only an icon.
extension View {
    func forgeIconButton(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .frame(minWidth: 44, minHeight: 44)  // minimum tap target
    }
}
