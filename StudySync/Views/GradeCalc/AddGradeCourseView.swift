import SwiftUI
import SwiftData

struct AddGradeCourseView: View {
    @Bindable var viewModel: GradeCalculatorViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "📘"
    @State private var colorHex = "#5B7FFF"
    @State private var targetGrade: Double = 90
    @State private var components: [DraftComponent] = [
        DraftComponent(name: "", weightText: "")
    ]

    @State private var weightWarningDismissed = false
    @State private var finalComponentId: UUID?

    struct DraftComponent: Identifiable {
        let id = UUID()
        var name: String
        var weightText: String

        var weight: Double? { Double(weightText) }
    }

    private var totalWeight: Double {
        components.compactMap(\.weight).reduce(0, +)
    }

    private var isWeightValid: Bool {
        abs(totalWeight - 100) < 0.01
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        components.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty && $0.weight != nil && $0.weight! > 0 } &&
        (isWeightValid || weightWarningDismissed)
    }

    // Preset emojis
    private let emojiOptions = ["📘", "📗", "📙", "📕", "🧮", "🔬", "🧪", "💻",
                                 "📊", "📐", "🎨", "🎵", "🌍", "⚖️", "🧬", "📝",
                                 "🏛️", "💰", "🗣️", "✍️", "🔢", "🧠", "📈", "🎓"]

    // Preset colors (hex strings)
    private let colorOptions = SSColor.palette

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SSSpacing.xxl) {
                    // Emoji picker
                    emojiPicker

                    // Course name
                    VStack(alignment: .leading, spacing: SSSpacing.sm) {
                        Text(L10n.gradeCourseName)
                            .font(SSFont.sectionHeader)
                            .foregroundStyle(.secondary)
                        TextField(L10n.gradeCoursePlaceholder, text: $name)
                            .font(SSFont.body)
                            .padding(SSSpacing.xl)
                            .background(
                                RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                                    .fill(SSColor.backgroundCard)
                            )
                    }

                    // Color picker
                    colorPicker

                    // Target grade
                    VStack(alignment: .leading, spacing: SSSpacing.sm) {
                        HStack {
                            Text(L10n.gradeTargetGrade)
                                .font(SSFont.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(targetGrade))%")
                                .font(SSFont.bodyMedium)
                                .foregroundStyle(Color(hex: colorHex))
                        }
                        Slider(value: $targetGrade, in: 50...100, step: 1)
                            .tint(Color(hex: colorHex))
                    }

                    // Components
                    componentsSection

                    // Weight warning
                    if !isWeightValid && !weightWarningDismissed {
                        HStack(spacing: SSSpacing.md) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(L10n.gradeWeightWarning)
                                .font(SSFont.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Button {
                                withAnimation(.spring(duration: 0.25)) {
                                    weightWarningDismissed = true
                                }
                                HapticEngine.shared.selection()
                            } label: {
                                Text(L10n.gradeWeightDismiss)
                                    .font(SSFont.chipLabel)
                                    .foregroundStyle(Color(hex: colorHex))
                            }
                        }
                        .padding(SSSpacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                                .fill(.orange.opacity(SSOpacity.shadow))
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Create button
                    Button { saveCourse() } label: {
                        Text(L10n.gradeAddCourse)
                            .font(SSFont.bodySemibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, SSSpacing.lg)
                            .background(
                                RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                                    .fill(canSave ? Color(hex: colorHex) : Color(hex: colorHex).opacity(SSOpacity.disabled))
                            )
                    }
                    .disabled(!canSave)
                }
                .padding(.horizontal, SSSpacing.xl)
                .padding(.top, SSSpacing.xl)
                .padding(.bottom, SSSpacing.xxl)
            }
            .background { SSColor.backgroundPrimary.ignoresSafeArea() }
            .navigationTitle(L10n.gradeAddCourse)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
        }
    }

    // MARK: - Emoji Picker

    private var emojiPicker: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: SSSpacing.md), count: 8)
        return LazyVGrid(columns: columns, spacing: SSSpacing.md) {
            ForEach(emojiOptions, id: \.self) { em in
                Text(em)
                    .font(.title2)
                    .frame(width: SSSize.emojiCircle, height: SSSize.emojiCircle)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                            .fill(emoji == em ? Color(hex: colorHex).opacity(SSOpacity.lightTint) : .clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                            .stroke(emoji == em ? Color(hex: colorHex) : .clear, lineWidth: SSBorder.selectionWidth)
                    )
                    .onTapGesture {
                        emoji = em
                        HapticEngine.shared.selection()
                    }
            }
        }
    }

    // MARK: - Color Picker

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: SSSpacing.sm) {
            let columns = Array(repeating: GridItem(.flexible()), count: 6)
            LazyVGrid(columns: columns, spacing: SSSpacing.md) {
                ForEach(colorOptions, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: SSSize.colorCircle, height: SSSize.colorCircle)
                        .overlay {
                            if colorHex == hex {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                        .scaleEffect(colorHex == hex ? 1.15 : 1.0)
                        .animation(.spring(duration: 0.2), value: colorHex)
                        .onTapGesture {
                            colorHex = hex
                            HapticEngine.shared.selection()
                        }
                }
            }
        }
    }

    // MARK: - Components Section

    private var componentsSection: some View {
        VStack(alignment: .leading, spacing: SSSpacing.lg) {
            HStack {
                Text(L10n.gradeComponents)
                    .font(SSFont.sectionHeader)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()

                let tw = Int(totalWeight)
                Text(L10n.gradeWeightSum(tw))
                    .font(SSFont.caption)
                    .foregroundStyle(abs(totalWeight - 100) < 0.01 ? .green : .orange)
            }

            ForEach($components) { $comp in
                HStack(spacing: SSSpacing.md) {
                    // Final designation radio
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            finalComponentId = (finalComponentId == comp.id) ? nil : comp.id
                        }
                        HapticEngine.shared.selection()
                    } label: {
                        Image(systemName: finalComponentId == comp.id ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundStyle(finalComponentId == comp.id ? Color(hex: colorHex) : Color.gray.opacity(0.4))
                    }
                    .buttonStyle(.plain)

                    TextField(L10n.gradeComponentPlaceholder, text: $comp.name)
                        .font(SSFont.body)

                    if finalComponentId == comp.id {
                        Text(L10n.gradeFinal)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color(hex: colorHex)))
                    }

                    HStack(spacing: SSSpacing.xs) {
                        TextField("0", text: $comp.weightText)
                            .font(SSFont.body)
                            .keyboardType(.decimalPad)
                            .frame(width: 50)
                            .multilineTextAlignment(.trailing)
                        Text("%")
                            .font(SSFont.body)
                            .foregroundStyle(.secondary)
                    }

                    if components.count > 1 {
                        Button {
                            if finalComponentId == comp.id { finalComponentId = nil }
                            components.removeAll { $0.id == comp.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red.opacity(0.7))
                        }
                    }
                }
                .padding(SSSpacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                        .fill(SSColor.backgroundCard)
                )
            }

            Button {
                components.append(DraftComponent(name: "", weightText: ""))
            } label: {
                HStack(spacing: SSSpacing.sm) {
                    Image(systemName: "plus.circle")
                    Text(L10n.gradeAddComponent)
                        .font(SSFont.chipLabel)
                }
                .foregroundStyle(Color(hex: colorHex))
            }
        }
    }

    // MARK: - Save

    private func saveCourse() {
        let course = GradeCourse(
            name: name.trimmingCharacters(in: .whitespaces),
            emoji: emoji,
            colorHex: colorHex,
            targetGradePercent: targetGrade
        )
        modelContext.insert(course)

        for (i, draft) in components.enumerated() {
            let comp = GradeComponent(
                name: draft.name.trimmingCharacters(in: .whitespaces),
                weightPercent: draft.weight ?? 0,
                sortOrder: i
            )
            comp.isFinal = (draft.id == finalComponentId)
            comp.course = course
            modelContext.insert(comp)
        }

        try? modelContext.save()
        GradeCourseSyncService.shared.pushCourse(course)
        for comp in course.components {
            GradeCourseSyncService.shared.pushComponent(comp, courseId: course.id)
        }

        HapticEngine.shared.success()
        dismiss()
    }
}
