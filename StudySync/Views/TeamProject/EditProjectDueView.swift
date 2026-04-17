import SwiftUI

struct EditProjectDueView: View {
    let due: ProjectDue
    let viewModel: TeamProjectViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var emoji: String
    @State private var dueDate: Date
    @State private var priority: DuePriority
    @State private var assignedMembers: Set<String> = []
    @State private var isSaving = false

    private let emojiOptions = ["📋", "📝", "📄", "📊", "🎯", "🔬", "💡", "🖥️", "📐", "🎨", "📖", "✏️"]

    private var canAssign: Bool {
        viewModel.currentProject?.canAssign ?? false
    }

    init(due: ProjectDue, viewModel: TeamProjectViewModel) {
        self.due = due
        self.viewModel = viewModel
        _title = State(initialValue: due.title)
        _description = State(initialValue: due.description)
        _emoji = State(initialValue: due.emoji)
        _dueDate = State(initialValue: due.dueDate)
        _priority = State(initialValue: due.priority)

        _assignedMembers = State(initialValue: Set(due.assignedTo))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.projectDueTitle)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField(L10n.projectDueTitle, text: $title)
                                .font(.system(size: 16))
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                )
                        }

                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.projectDueDesc)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField(L10n.projectDueDesc, text: $description, axis: .vertical)
                                .font(.system(size: 15))
                                .lineLimit(3...6)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                )
                        }

                        // Emoji
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.projectEmoji)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                                ForEach(emojiOptions, id: \.self) { option in
                                    Button {
                                        emoji = option
                                        HapticEngine.shared.selection()
                                    } label: {
                                        Text(option)
                                            .font(.system(size: 24))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .fill(emoji == option ? Color(hex: "#5B7FFF").opacity(0.15) : Color.clear)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Due date
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.projectDueDate)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                            DatePicker("", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                )
                        }

                        // Priority
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.projectDuePriority)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 10) {
                                ForEach(DuePriority.allCases, id: \.self) { p in
                                    Button {
                                        priority = p
                                        HapticEngine.shared.selection()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: p.icon)
                                                .font(.system(size: 12))
                                            Text(p.displayName)
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .foregroundStyle(priority == p ? .white : Color(hex: p.colorHex))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule().fill(
                                                priority == p ? Color(hex: p.colorHex) : Color(hex: p.colorHex).opacity(0.12)
                                            )
                                        )
                                    }
                                }
                            }
                        }

                        // Assign (only if >=2 members)
                        if canAssign, let members = viewModel.currentProject?.memberProfiles {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.projectDueAssign)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(members) { member in
                                            let selected = assignedMembers.contains(member.id)
                                            Button {
                                                if selected {
                                                    assignedMembers.remove(member.id)
                                                } else {
                                                    assignedMembers.insert(member.id)
                                                }
                                                HapticEngine.shared.selection()
                                            } label: {
                                                VStack(spacing: 4) {
                                                    ZStack(alignment: .bottomTrailing) {
                                                        Text(member.avatarEmoji)
                                                            .font(.system(size: 24))
                                                            .frame(width: 36, height: 36)
                                                            .background(Circle().fill(Color(.tertiarySystemFill)))
                                                        if selected {
                                                            Image(systemName: "checkmark.circle.fill")
                                                                .font(.system(size: 14))
                                                                .foregroundStyle(.white, Color(hex: "#5B7FFF"))
                                                                .offset(x: 4, y: 4)
                                                        }
                                                    }
                                                    Text(member.displayName)
                                                        .font(.system(size: 10))
                                                        .foregroundStyle(.primary)
                                                        .lineLimit(1)
                                                }
                                                .frame(width: 60)
                                                .padding(.vertical, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .fill(selected ? Color(hex: "#5B7FFF").opacity(0.1) : Color.clear)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .stroke(selected ? Color(hex: "#5B7FFF") : Color.clear, lineWidth: 1.5)
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(L10n.projectEditDue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveDue()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(L10n.save)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func saveDue() {
        isSaving = true
        Task {
            await viewModel.updateFullDue(
                due,
                title: title.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces),
                emoji: emoji,
                dueDate: dueDate,
                priority: priority,
                assignedTo: viewModel.currentProject?.memberProfiles.filter { assignedMembers.contains($0.id) } ?? []
            )
            isSaving = false
            HapticEngine.shared.success()
            dismiss()
        }
    }
}
