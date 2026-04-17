import SwiftUI
import SwiftData

struct GradeCourseDetailView: View {
    @Bindable var course: GradeCourse
    @Bindable var viewModel: GradeCalculatorViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddComponent = false
    @State private var editingComponent: GradeComponent?
    @State private var showingDeleteAlert = false
    @State private var showingEditCourse = false

    private var courseColor: Color { Color(hex: course.colorHex) }

    var body: some View {
        ScrollView {
            VStack(spacing: SSSpacing.xl) {
                // Score summary
                scoreSummaryCard

                // "What you need" card
                neededScoreCard

                // Components list
                componentsSection

                // Actions
                actionsSection
            }
            .padding(.horizontal, SSSpacing.xl)
            .padding(.top, SSSpacing.md)
            .padding(.bottom, SSSpacing.xxxl)
        }
        .background { SSColor.backgroundPrimary.ignoresSafeArea() }
        .navigationTitle(course.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEditCourse = true
                } label: {
                    Image(systemName: "pencil.circle")
                        .foregroundStyle(courseColor)
                }
            }
        }
        .sheet(isPresented: $showingAddComponent) {
            AddComponentSheet(course: course, viewModel: viewModel)
        }
        .sheet(item: $editingComponent) { comp in
            EditGradeComponentView(component: comp, course: course, viewModel: viewModel)
        }
        .sheet(isPresented: $showingEditCourse) {
            EditGradeCourseView(course: course, viewModel: viewModel)
        }
        .alert(L10n.gradeDeleteCourse, isPresented: $showingDeleteAlert) {
            Button(L10n.gradeConfirmDelete, role: .destructive) {
                viewModel.deleteCourse(course, context: modelContext)
                dismiss()
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.gradeDeleteWarning)
        }
    }

    // MARK: - Score Summary

    private var scoreSummaryCard: some View {
        VStack(spacing: SSSpacing.lg) {
            // Emoji + current grade
            HStack(spacing: SSSpacing.xl) {
                Text(course.emoji)
                    .font(.system(size: 40))
                    .frame(width: 60, height: 60)
                    .background(courseColor.opacity(SSOpacity.tagBackground), in: RoundedRectangle(cornerRadius: SSRadius.medium))

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.gradeConfirmedScore)
                        .font(SSFont.caption)
                        .foregroundStyle(.secondary)
                    if course.enteredWeight > 0 {
                        Text(String(format: "%.1f%%", course.currentWeightedScore))
                            .font(SSFont.countdownLarge)
                            .foregroundStyle(courseColor)
                    } else {
                        Text("--")
                            .font(SSFont.countdownLarge)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Target ring
                ZStack {
                    Circle()
                        .stroke(courseColor.opacity(SSOpacity.tagBackground), lineWidth: SSSize.ringCardLine)
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(courseColor, style: StrokeStyle(lineWidth: SSSize.ringCardLine, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(course.targetGradePercent))%")
                        .font(SSFont.captionMedium)
                        .foregroundStyle(.secondary)
                }
                .frame(width: SSSize.ringCard, height: SSSize.ringCard)
            }

            // Weight usage bar
            HStack(spacing: SSSpacing.sm) {
                Text(L10n.gradeWeightSum(Int(course.totalWeight)))
                    .font(SSFont.caption)
                    .foregroundStyle(course.isWeightValid ? Color.secondary : Color.orange)
                Spacer()
                Text("\(course.components.filter(\.hasScore).count)/\(course.components.count) \(L10n.gradeScore)")
                    .font(SSFont.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(SSSpacing.xl)
        .ssCard(color: courseColor)
    }

    private var ringProgress: Double {
        guard course.targetGradePercent > 0 else { return 0 }
        return min(course.currentWeightedScore / course.targetGradePercent, 1.0)
    }

    // MARK: - Needed Score Card

    @ViewBuilder
    private var neededScoreCard: some View {
        if let needed = course.neededScore, (course.finalComponent != nil ? !course.finalComponent!.hasScore : course.remainingWeight > 0) {
            VStack(spacing: SSSpacing.lg) {
                HStack(spacing: SSSpacing.md) {
                    Image(systemName: "target")
                        .font(.title2)
                        .foregroundStyle(courseColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.gradeFinalNeeded)
                            .font(SSFont.caption)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", needed))
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(needed <= 100 ? courseColor : .orange)
                            Text("%")
                                .font(SSFont.heading2)
                                .foregroundStyle(needed <= 100 ? courseColor : .orange)
                        }
                    }
                    Spacer()
                }

                if needed > 100 {
                    HStack(spacing: SSSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                        Text(L10n.gradeTargetUnreachable)
                            .font(SSFont.caption)
                    }
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SSSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.medium)
                            .fill(.orange.opacity(SSOpacity.tagBackground))
                    )
                } else if needed <= 0 {
                    HStack(spacing: SSSpacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text(L10n.gradeAlreadyPassed)
                            .font(SSFont.caption)
                    }
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Breakdown
                HStack(spacing: SSSpacing.xl) {
                    miniStat(label: L10n.gradeTarget, value: "\(Int(course.targetGradePercent))%")
                    miniStat(label: L10n.gradeCurrentGrade, value: String(format: "%.1f%%", course.currentWeightedScore))
                    miniStat(label: L10n.gradeWeight, value: String(format: "%.0f%%", course.remainingWeight))
                }
            }
            .padding(SSSpacing.xl)
            .ssCard(color: courseColor)
        } else if course.enteredWeight > 0 && course.remainingWeight == 0 {
            // All entered
            HStack(spacing: SSSpacing.md) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.gradeAlreadyPassed)
                        .font(SSFont.bodyMedium)
                        .foregroundStyle(.green)
                    Text(String(format: "%.1f%% / %d%%", course.currentWeightedScore, Int(course.targetGradePercent)))
                        .font(SSFont.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(SSSpacing.xl)
            .ssCard(color: .green)
        }
    }

    private func miniStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(SSFont.bodyMedium)
            Text(label)
                .font(SSFont.micro)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Components

    private var componentsSection: some View {
        VStack(alignment: .leading, spacing: SSSpacing.lg) {
            Text(L10n.gradeComponents)
                .font(SSFont.sectionHeader)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if course.sortedComponents.isEmpty {
                VStack(spacing: SSSpacing.md) {
                    Image(systemName: "tray")
                        .font(SSFont.emojiLarge)
                        .foregroundStyle(.tertiary)
                    Text(L10n.gradeNoComponents)
                        .font(SSFont.secondary)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, SSSpacing.xxxl)
            } else {
                ForEach(course.sortedComponents) { comp in
                    componentRow(comp)
                }
            }

            // Add component
            Button { showingAddComponent = true } label: {
                HStack(spacing: SSSpacing.sm) {
                    Image(systemName: "plus.circle")
                    Text(L10n.gradeAddComponent)
                        .font(SSFont.chipLabel)
                }
                .foregroundStyle(courseColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SSSpacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                        .strokeBorder(courseColor.opacity(SSOpacity.elevatedShadow), style: StrokeStyle(lineWidth: 1, dash: [6, 3]))
                )
            }
        }
        .padding(SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
    }

    private func componentRow(_ comp: GradeComponent) -> some View {
        Button {
            editingComponent = comp
        } label: {
            HStack(spacing: SSSpacing.md) {
                // Weight badge
                Text("\(Int(comp.weightPercent))%")
                    .font(SSFont.captionMedium)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 28)
                    .background(Capsule().fill(courseColor))

                // Name + final badge
                HStack(spacing: SSSpacing.sm) {
                    Text(comp.name)
                        .font(SSFont.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if comp.isFinal {
                        Text(L10n.gradeFinal)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(courseColor))
                    }
                }

                Spacer()

                // Score
                if let pct = comp.effectivePercent {
                    Text(String(format: "%.1f%%", pct))
                        .font(SSFont.bodyMedium)
                        .foregroundStyle(courseColor)
                } else {
                    Text(L10n.gradeScoreNotEntered)
                        .font(SSFont.caption)
                        .foregroundStyle(.tertiary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, SSSpacing.lg)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                editingComponent = comp
            } label: {
                Label(L10n.gradeEditScore, systemImage: "pencil")
            }
            Button {
                // Clear other finals, set this one
                for c in course.components { c.isFinal = false }
                comp.isFinal = true
                try? modelContext.save()
                GradeCourseSyncService.shared.pushComponent(comp, courseId: course.id)
                HapticEngine.shared.selection()
            } label: {
                Label(comp.isFinal ? L10n.gradeIsFinal : L10n.gradeSetAsFinal, systemImage: comp.isFinal ? "checkmark.circle.fill" : "star")
            }
            Button(role: .destructive) {
                viewModel.deleteComponent(comp, course: course, context: modelContext)
            } label: {
                Label(L10n.gradeDeleteComponent, systemImage: "trash")
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: SSSpacing.md) {
            Button {
                viewModel.archiveCourse(course, context: modelContext)
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "archivebox")
                    Text(L10n.gradeArchiveCourse)
                }
                .font(SSFont.body)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SSSpacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                        .fill(.orange.opacity(SSOpacity.shadow))
                )
            }

            Button {
                showingDeleteAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text(L10n.gradeDeleteCourse)
                }
                .font(SSFont.body)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SSSpacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                        .fill(.red.opacity(SSOpacity.shadow))
                )
            }
        }
    }
}

// MARK: - Add Component Sheet

struct AddComponentSheet: View {
    let course: GradeCourse
    @Bindable var viewModel: GradeCalculatorViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var weightText = ""

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (Double(weightText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: SSSpacing.xxl) {
                VStack(alignment: .leading, spacing: SSSpacing.sm) {
                    Text(L10n.gradeComponentName)
                        .font(SSFont.sectionHeader)
                        .foregroundStyle(.secondary)
                    TextField(L10n.gradeComponentPlaceholder, text: $name)
                        .font(SSFont.body)
                        .padding(SSSpacing.xl)
                        .background(
                            RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                                .fill(SSColor.backgroundCard)
                        )
                }

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

                Spacer()
            }
            .padding(.horizontal, SSSpacing.xl)
            .padding(.top, SSSpacing.xxl)
            .background { SSColor.backgroundPrimary.ignoresSafeArea() }
            .navigationTitle(L10n.gradeAddComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        viewModel.addComponent(
                            to: course,
                            name: name.trimmingCharacters(in: .whitespaces),
                            weight: Double(weightText) ?? 0,
                            context: modelContext
                        )
                        HapticEngine.shared.success()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Edit Course Sheet

struct EditGradeCourseView: View {
    @Bindable var course: GradeCourse
    @Bindable var viewModel: GradeCalculatorViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var emoji: String
    @State private var colorHex: String
    @State private var targetGrade: Double

    private let emojiOptions = ["📘", "📗", "📙", "📕", "🧮", "🔬", "🧪", "💻",
                                 "📊", "📐", "🎨", "🎵", "🌍", "⚖️", "🧬", "📝",
                                 "🏛️", "💰", "🗣️", "✍️", "🔢", "🧠", "📈", "🎓"]
    private let colorOptions = SSColor.palette  // [String] hex values

    init(course: GradeCourse, viewModel: GradeCalculatorViewModel) {
        self.course = course
        self.viewModel = viewModel
        _name = State(initialValue: course.name)
        _emoji = State(initialValue: course.emoji)
        _colorHex = State(initialValue: course.colorHex)
        _targetGrade = State(initialValue: course.targetGradePercent)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SSSpacing.xxl) {
                    // Emoji
                    let columns = Array(repeating: GridItem(.flexible(), spacing: SSSpacing.md), count: 8)
                    LazyVGrid(columns: columns, spacing: SSSpacing.md) {
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
                                .onTapGesture { emoji = em; HapticEngine.shared.selection() }
                        }
                    }

                    // Name
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

                    // Color
                    let colorCols = Array(repeating: GridItem(.flexible()), count: 6)
                    LazyVGrid(columns: colorCols, spacing: SSSpacing.md) {
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
                                .onTapGesture { colorHex = hex; HapticEngine.shared.selection() }
                        }
                    }

                    // Target
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
                }
                .padding(.horizontal, SSSpacing.xl)
                .padding(.top, SSSpacing.xl)
                .padding(.bottom, SSSpacing.xxl)
            }
            .background { SSColor.backgroundPrimary.ignoresSafeArea() }
            .navigationTitle(L10n.gradeEditCourse)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        course.name = name.trimmingCharacters(in: .whitespaces)
                        course.emoji = emoji
                        course.colorHex = colorHex
                        course.targetGradePercent = targetGrade
                        try? modelContext.save()
                        GradeCourseSyncService.shared.pushCourse(course)
                        HapticEngine.shared.success()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
