import SwiftUI

// MARK: - Sheet Toolbar (Cancel / Save)
//
// Standardizes the Cancel-on-the-left, Save-on-the-right toolbar layout
// used by every modal sheet in the app (AddEvent, AddTodo, EditTodo,
// CreateProject, AddProjectDue, AddCalendarEvent, ManualTravelForm, ...).
//
// Apply via `.ssSheetToolbar(...)` on the sheet's NavigationStack content.
// Cancel calls `dismiss()` from the environment automatically; Save's
// closure is provided by the caller. `disabled` is the Save button's
// disabled state (e.g. "title is empty").

extension View {
    /// Standard sheet toolbar: Cancel (leading) + Save (trailing, semibold).
    ///
    /// - Parameters:
    ///   - cancelLabel: defaults to L10n.cancel
    ///   - saveLabel: defaults to L10n.save
    ///   - saveDisabled: true to grey out Save (e.g. validation failed)
    ///   - onCancel: optional override; defaults to `dismiss()`
    ///   - onSave: required save action
    func ssSheetToolbar(
        cancelLabel: String? = nil,
        saveLabel: String? = nil,
        saveDisabled: Bool = false,
        onCancel: (() -> Void)? = nil,
        onSave: @escaping () -> Void
    ) -> some View {
        modifier(SSSheetToolbarModifier(
            cancelLabel: cancelLabel ?? L10n.cancel,
            saveLabel: saveLabel ?? L10n.save,
            saveDisabled: saveDisabled,
            onCancel: onCancel,
            onSave: onSave
        ))
    }
}

private struct SSSheetToolbarModifier: ViewModifier {
    let cancelLabel: String
    let saveLabel: String
    let saveDisabled: Bool
    let onCancel: (() -> Void)?
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(cancelLabel) {
                    if let onCancel { onCancel() } else { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(saveLabel, action: onSave)
                    .fontWeight(.semibold)
                    .disabled(saveDisabled)
            }
        }
    }
}


// MARK: - Primary Button
//
// One reusable styled "primary action" button for empty states, paywalls,
// and forms — same height, radius, gradient, and font weight everywhere.
// Replaces ad-hoc `Capsule().fill(SSColor.brand)` + `.padding(...)` blocks
// scattered across ~10 callers that all looked subtly different.
//
// Use the modifier on a Text or HStack(label) — it adds padding +
// background + radius. For a label-only convenience use
// `SSPrimaryButton(title:icon:action:)`.

extension View {
    /// Style content as a primary action button (capsule, brand gradient,
    /// white text). Apply to the LABEL inside a Button — the modifier
    /// adds padding + background, NOT a Button wrapper.
    func ssPrimaryButtonStyle(color: Color = SSColor.brand, fullWidth: Bool = false) -> some View {
        self
            .font(SSFont.bodySemibold)
            .foregroundStyle(.white)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, SSSpacing.xxxl)
            .padding(.vertical, SSSpacing.lg)
            .background(Capsule().fill(color.gradient))
    }
}

/// Convenience wrapper: `SSPrimaryButton(title: "Save", icon: "plus") { ... }`.
struct SSPrimaryButton: View {
    let title: String
    let icon: String?
    let color: Color
    let fullWidth: Bool
    let action: () -> Void

    init(
        title: String,
        icon: String? = nil,
        color: Color = SSColor.brand,
        fullWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.fullWidth = fullWidth
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: SSSpacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(SSFont.bodySmallSemibold)
                }
                Text(title)
            }
            .ssPrimaryButtonStyle(color: color, fullWidth: fullWidth)
        }
    }
}
