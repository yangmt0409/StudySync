import SwiftUI
import UIKit

// MARK: - Keyboard Dismissal Helpers
//
// iOS doesn't auto-dismiss the soft keyboard for `TextField(axis: .vertical)`
// (multi-line) since Return inserts a newline. Single-line TextFields inside a
// Form dismiss when Return is hit on a hardware keyboard but NOT when typing
// on the on-screen keyboard if there's no accessory bar.
//
// We standardize on TWO mechanisms together:
//
//   1. `.scrollDismissesKeyboard(.interactively)` on the scroll container
//      (Form / List / ScrollView). Lets users drag down on the content to
//      collapse the keyboard. iOS 16+.
//
//   2. `.dismissKeyboardToolbar()` adds a "完成" button to the keyboard's
//      input accessory toolbar. Always-available escape hatch even when the
//      content isn't tall enough to scroll.
//
// Apply BOTH on any view with `TextField` / `TextEditor` / `SecureField`.
// The two are cheap and complementary — `.scrollDismissesKeyboard` is the
// "natural" interaction; the Done button is the discoverable backup.

extension View {
    /// Add a "完成" (Done) button to the keyboard accessory toolbar that
    /// resigns the first responder when tapped. Apply at the same level as
    /// `.toolbar { ... }` works (typically inside a NavigationStack body).
    ///
    /// Unconditional — the toolbar only appears while a TextField is focused,
    /// so adding it on a view without text input is harmless.
    func dismissKeyboardToolbar() -> some View {
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n.done) {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                .fontWeight(.semibold)
            }
        }
    }
}
