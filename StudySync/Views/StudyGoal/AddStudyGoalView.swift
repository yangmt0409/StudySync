import SwiftUI
import SwiftData

struct AddStudyGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var emoji = "📚"
    @State private var colorHex = "#5B7FFF"
    @State private var frequency: GoalFrequency = .daily

    private let emojiOptions = ["📚", "💻", "🏃", "🎵", "🎨", "📝", "🧘", "🔬", "📖", "🗣️", "✍️", "🧠"]
    private let colorOptions = [
        "#5B7FFF", "#FF6B6B", "#4ECDC4", "#FFD93D",
        "#6C5CE7", "#A8E6CF", "#FF8A5C", "#EA8685",
        "#778BEB", "#63CDDA", "#F19066", "#B8E994"
    ]

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Title
                Section {
                    TextField(L10n.goalTitlePlaceholder, text: $title)
                        .font(.system(size: 16))
                } header: {
                    Text(L10n.goalNameSection)
                }

                // Emoji picker
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(emojiOptions, id: \.self) { option in
                            Button {
                                emoji = option
                                HapticEngine.shared.selection()
                            } label: {
                                Text(option)
                                    .font(.system(size: 28))
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .fill(emoji == option
                                                  ? Color(hex: colorHex).opacity(0.15)
                                                  : Color(.tertiarySystemFill))
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(emoji == option ? Color(hex: colorHex) : .clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(L10n.iconSection)
                }

                // Color picker
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Button {
                                colorHex = hex
                                HapticEngine.shared.selection()
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(.white, lineWidth: colorHex == hex ? 3 : 0)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color(hex: hex).opacity(0.5), lineWidth: colorHex == hex ? 1 : 0)
                                            .padding(-2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(L10n.cardColor)
                }

                // Frequency
                Section {
                    Picker(L10n.goalFrequency, selection: $frequency) {
                        ForEach(GoalFrequency.allCases, id: \.rawValue) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text(L10n.goalFrequency)
                } footer: {
                    Text(frequency == .daily
                         ? L10n.goalDailyDesc
                         : L10n.goalWeeklyDesc)
                }

                // Preview
                Section {
                    previewCard
                } header: {
                    Text(L10n.preview)
                }

                // Milestone info
                Section {
                    let milestones = Milestone.milestones(for: frequency)
                    ForEach(milestones, id: \.count) { ms in
                        HStack(spacing: 10) {
                            Text(ms.emoji)
                                .font(.system(size: 20))
                            Text(ms.title)
                                .font(.system(size: 14))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(frequency == .daily
                                 ? L10n.goalDayCount(ms.count)
                                 : L10n.goalWeekCount(ms.count))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(L10n.goalMilestones)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(L10n.goalAddGoal)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.save) {
                        saveGoal()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 4) {
                Text(title.isEmpty ? L10n.goalTitlePlaceholder : title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(title.isEmpty ? .secondary : .primary)

                Text(frequency.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(hex: colorHex))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(hex: colorHex).opacity(0.12).clipShape(Capsule()))
            }

            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 28))
                .foregroundStyle(Color(hex: colorHex))
        }
        .padding(.vertical, 4)
    }

    // MARK: - Save

    private func saveGoal() {
        let goal = StudyGoal(
            title: title.trimmingCharacters(in: .whitespaces),
            emoji: emoji,
            colorHex: colorHex,
            frequency: frequency
        )
        modelContext.insert(goal)
        do {
            try modelContext.save()
            debugPrint("[StudyGoal] saved goal: \(goal.title)")
            StudyGoalSyncService.shared.pushGoal(goal)
        } catch {
            debugPrint("[StudyGoal] save error: \(error)")
        }
        HapticEngine.shared.lightImpact()
        dismiss()
    }
}

#Preview {
    AddStudyGoalView()
        .modelContainer(for: [StudyGoal.self, CheckInRecord.self], inMemory: true)
}
