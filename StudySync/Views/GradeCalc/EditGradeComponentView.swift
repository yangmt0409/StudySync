import SwiftUI
import SwiftData

struct EditGradeComponentView: View {
    @Bindable var component: GradeComponent
    let course: GradeCourse
    @Bindable var viewModel: GradeCalculatorViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var inputMode: ComponentInputMode
    @State private var numeratorText: String
    @State private var denominatorText: String
    @State private var percentText: String
    @State private var compName: String
    @State private var weightText: String

    private var courseColor: Color { Color(hex: course.colorHex) }

    init(component: GradeComponent, course: GradeCourse, viewModel: GradeCalculatorViewModel) {
        self.component = component
        self.course = course
        self.viewModel = viewModel
        _inputMode = State(initialValue: component.inputMode)
        _numeratorText = State(initialValue: component.scoreNumerator.map { String(format: "%g", $0) } ?? "")
        _denominatorText = State(initialValue: component.scoreDenominator.map { String(format: "%g", $0) } ?? "")
        _percentText = State(initialValue: component.scorePercent.map { String(format: "%g", $0) } ?? "")
        _compName = State(initialValue: component.name)
        _weightText = State(initialValue: String(format: "%g", component.weightPercent))
    }

    private var effectivePercent: Double? {
        switch inputMode {
        case .raw:
            guard let num = Double(numeratorText), let den = Double(denominatorText), den > 0 else { return nil }
            return (num / den) * 100
        case .percent:
            return Double(percentText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: SSSpacing.xxl) {
                // Component info
                VStack(alignment: .leading, spacing: SSSpacing.sm) {
                    Text(L10n.gradeComponentName)
                        .font(SSFont.sectionHeader)
                        .foregroundStyle(.secondary)
                    TextField(L10n.gradeComponentPlaceholder, text: $compName)
                        .font(SSFont.body)
                        .padding(SSSpacing.xl)
                        .background(
                            RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                                .fill(SSColor.backgroundCard)
                        )
                }

                // Weight
                VStack(alignment: .leading, spacing: SSSpacing.sm) {
                    Text(L10n.gradeWeight)
                        .font(SSFont.sectionHeader)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("0", text: $weightText)
                            .font(SSFont.body)
                            .keyboardType(.decimalPad)
                        Text("%")
                            .font(SSFont.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(SSSpacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                            .fill(SSColor.backgroundCard)
                    )
                }

                // Input mode picker
                VStack(alignment: .leading, spacing: SSSpacing.sm) {
                    Text(L10n.gradeScore)
                        .font(SSFont.sectionHeader)
                        .foregroundStyle(.secondary)

                    Picker("", selection: $inputMode) {
                        ForEach(ComponentInputMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Score input
                    if inputMode == .raw {
                        HStack(spacing: SSSpacing.md) {
                            TextField("0", text: $numeratorText)
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .padding(SSSpacing.lg)
                                .background(
                                    RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                                        .fill(SSColor.backgroundCard)
                                )

                            Text("/")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.secondary)

                            TextField("100", text: $denominatorText)
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .padding(SSSpacing.lg)
                                .background(
                                    RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                                        .fill(SSColor.backgroundCard)
                                )
                        }
                    } else {
                        HStack {
                            TextField("0", text: $percentText)
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .padding(SSSpacing.lg)
                                .background(
                                    RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                                        .fill(SSColor.backgroundCard)
                                )
                            Text("%")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Effective score preview
                if let eff = effectivePercent {
                    HStack(spacing: SSSpacing.md) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(courseColor)
                        Text(L10n.gradeEffective)
                            .font(SSFont.secondary)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.1f%%", eff))
                            .font(SSFont.bodySemibold)
                            .foregroundStyle(courseColor)
                    }
                    .padding(SSSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                            .fill(courseColor.opacity(SSOpacity.tagBackground))
                    )
                }

                // Final designation toggle
                Button {
                    // Toggle: if already final, unset; otherwise set this and clear others
                    if component.isFinal {
                        component.isFinal = false
                    } else {
                        for c in course.components { c.isFinal = false }
                        component.isFinal = true
                    }
                    try? modelContext.save()
                    for c in course.components {
                        GradeCourseSyncService.shared.pushComponent(c, courseId: course.id)
                    }
                    HapticEngine.shared.selection()
                } label: {
                    HStack(spacing: SSSpacing.md) {
                        Image(systemName: component.isFinal ? "star.fill" : "star")
                            .foregroundStyle(component.isFinal ? courseColor : .secondary)
                        Text(component.isFinal ? L10n.gradeIsFinal : L10n.gradeSetAsFinal)
                            .font(SSFont.body)
                            .foregroundStyle(.primary)
                        Spacer()
                        if component.isFinal {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(courseColor)
                        }
                    }
                    .padding(SSSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                            .fill(component.isFinal ? courseColor.opacity(SSOpacity.tagBackground) : SSColor.backgroundCard)
                    )
                }
                .buttonStyle(.plain)

                // Clear score button
                if component.hasScore {
                    Button {
                        numeratorText = ""
                        denominatorText = ""
                        percentText = ""
                    } label: {
                        HStack(spacing: SSSpacing.sm) {
                            Image(systemName: "eraser")
                            Text(L10n.gradeScoreNotEntered)
                        }
                        .font(SSFont.chipLabel)
                        .foregroundStyle(.red)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, SSSpacing.xl)
            .padding(.top, SSSpacing.xxl)
            .background { SSColor.backgroundPrimary.ignoresSafeArea() }
            .navigationTitle(L10n.gradeEditScore)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) { saveScore() }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Save

    private func saveScore() {
        component.name = compName.trimmingCharacters(in: .whitespaces)
        component.weightPercent = Double(weightText) ?? component.weightPercent
        component.inputMode = inputMode

        switch inputMode {
        case .raw:
            component.scoreNumerator = Double(numeratorText)
            component.scoreDenominator = Double(denominatorText)
            component.scorePercent = nil
        case .percent:
            component.scorePercent = Double(percentText)
            component.scoreNumerator = nil
            component.scoreDenominator = nil
        }

        viewModel.updateComponent(component, course: course, context: modelContext)
        HapticEngine.shared.success()
        dismiss()
    }
}
