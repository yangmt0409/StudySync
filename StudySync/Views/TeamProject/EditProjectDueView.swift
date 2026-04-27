import SwiftUI

struct EditProjectDueView: View {
    let due: ProjectDue
    let viewModel: TeamProjectViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass

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
                    VStack(spacing: SSSpacing.xxl) {
                        // Title
                        VStack(alignment: .leading, spacing: SSSpacing.md) {
                            Text(L10n.projectDueTitle)
                                .font(SSFont.chipLabel)
                                .foregroundStyle(.secondary)
                            TextField(L10n.projectDueTitle, text: $title)
                                .font(SSFont.body)
                                .padding(SSSpacing.lgXl)
                                .background(
                                    RoundedRectangle(cornerRadius: SSRadius.fieldCard, style: .continuous)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                )
                        }

                        // Description
                        VStack(alignment: .leading, spacing: SSSpacing.md) {
                            Text(L10n.projectDueDesc)
                                .font(SSFont.chipLabel)
                                .foregroundStyle(.secondary)
                            TextField(L10n.projectDueDesc, text: $description, axis: .vertical)
                                .font(.system(size: 15))
                                .lineLimit(3...6)
                                .padding(SSSpacing.lgXl)
                                .background(
                                    RoundedRectangle(cornerRadius: SSRadius.fieldCard, style: .continuous)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                )
                        }

                        // Emoji
                        VStack(alignment: .leading, spacing: SSSpacing.md) {
                            Text(L10n.projectEmoji)
                                .font(SSFont.chipLabel)
                                .foregroundStyle(.secondary)
                            LazyVGrid(columns: iPadGridColumns(iPhone: 6, spacing: 6, sizeClass: hSizeClass), spacing: 6) {
                                ForEach(emojiOptions, id: \.self) { option in
                                    Button {
                                        emoji = option
                                        HapticEngine.shared.selection()
                                    } label: {
                                        Text(option)
                                            .font(.system(size: 24))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, SSSpacing.sm)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .fill(emoji == option ? SSColor.brand.opacity(SSOpacity.lightTint) : Color.clear)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Due date
                        VStack(alignment: .leading, spacing: SSSpacing.md) {
                            Text(L10n.projectDueDate)
                                .font(SSFont.chipLabel)
                                .foregroundStyle(.secondary)
                            DatePicker("", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .padding(SSSpacing.lgXl)
                                .background(
                                    RoundedRectangle(cornerRadius: SSRadius.fieldCard, style: .continuous)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                )
                        }

                        // Priority
                        VStack(alignment: .leading, spacing: SSSpacing.md) {
                            Text(L10n.projectDuePriority)
                                .font(SSFont.chipLabel)
                                .foregroundStyle(.secondary)
                            HStack(spacing: SSSpacing.mdLg) {
                                ForEach(DuePriority.allCases, id: \.self) { p in
                                    Button {
                                        priority = p
                                        HapticEngine.shared.selection()
                                    } label: {
                                        HStack(spacing: SSSpacing.xs) {
                                            Image(systemName: p.icon)
                                                .font(SSFont.footnote)
                                            Text(p.displayName)
                                                .font(SSFont.chipLabel)
                                        }
                                        .foregroundStyle(priority == p ? .white : Color(hex: p.colorHex))
                                        .padding(.horizontal, SSSpacing.lgXl)
                                        .padding(.vertical, SSSpacing.md)
                                        .background(
                                            Capsule().fill(
                                                priority == p ? Color(hex: p.colorHex) : Color(hex: p.colorHex).opacity(SSOpacity.tagBackground)
                                            )
                                        )
                                    }
                                }
                            }
                        }

                        // Assign (only if >=2 members)
                        if canAssign, let members = viewModel.currentProject?.memberProfiles {
                            VStack(alignment: .leading, spacing: SSSpacing.md) {
                                Text(L10n.projectDueAssign)
                                    .font(SSFont.chipLabel)
                                    .foregroundStyle(.secondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: SSSpacing.mdLg) {
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
                                                VStack(spacing: SSSpacing.xs) {
                                                    ZStack(alignment: .bottomTrailing) {
                                                        Text(member.avatarEmoji)
                                                            .font(.system(size: 24))
                                                            .frame(width: 36, height: 36)
                                                            .background(Circle().fill(Color(.tertiarySystemFill)))
                                                        if selected {
                                                            Image(systemName: "checkmark.circle.fill")
                                                                .font(.system(size: 14))
                                                                .foregroundStyle(.white, SSColor.brand)
                                                                .offset(x: 4, y: 4)
                                                        }
                                                    }
                                                    Text(member.displayName)
                                                        .font(SSFont.micro)
                                                        .foregroundStyle(.primary)
                                                        .lineLimit(1)
                                                }
                                                .frame(width: 60)
                                                .padding(.vertical, SSSpacing.md)
                                                .background(
                                                    RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                                                        .fill(selected ? SSColor.brand.opacity(0.1) : Color.clear)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                                                        .stroke(selected ? SSColor.brand : Color.clear, lineWidth: 1.5)
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, SSSpacing.xxl)
                    .padding(.top, SSSpacing.md)
                    .padding(.bottom, SSSpacing.xxl)
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
