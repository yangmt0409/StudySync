import SwiftUI

struct ProjectDueRow: View {
    let due: ProjectDue
    let project: TeamProject
    let viewModel: TeamProjectViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var showAssignSheet = false
    @State private var showEditSheet = false

    private var projectColor: Color { Color(hex: project.colorHex) }
    private var priorityColor: Color { Color(hex: due.priority.colorHex) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Completion toggle
                Button {
                    Task {
                        await viewModel.toggleDueCompletion(due)
                        HapticEngine.shared.lightImpact()
                    }
                } label: {
                    Image(systemName: due.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(due.isCompleted ? .green : projectColor)
                }
                .buttonStyle(.plain)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(due.emoji)
                            .font(.system(size: 14))
                        Text(due.title)
                            .font(.system(size: 15, weight: .medium))
                            .strikethrough(due.isCompleted, color: .secondary)
                            .foregroundStyle(due.isCompleted ? .secondary : .primary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        // Priority
                        HStack(spacing: 2) {
                            Image(systemName: due.priority.icon)
                                .font(.system(size: 9))
                            Text(due.priority.displayName)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(priorityColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(priorityColor.opacity(0.12).clipShape(Capsule()))

                        // Due date
                        dueDateLabel
                    }
                }

                Spacer()

                // Assignee
                assigneeView
            }
            .padding(14)

            // Description (if any)
            if !due.description.isEmpty && !due.isCompleted {
                Divider().padding(.horizontal, 14)
                Text(due.description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .lineLimit(2)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    due.isOverdue ? Color.red.opacity(0.3) :
                    due.isUrgent ? Color.orange.opacity(0.3) : Color.clear,
                    lineWidth: 1.5
                )
        )
        .opacity(due.isCompleted ? 0.7 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            showEditSheet = true
        }
        .sheet(isPresented: $showEditSheet) {
            EditProjectDueView(due: due, viewModel: viewModel)
        }
        .sheet(isPresented: $showAssignSheet) {
            AssignMemberSheet(due: due, project: project, viewModel: viewModel)
        }
        .contextMenu {
            Button {
                showEditSheet = true
            } label: {
                Label(L10n.projectEditDue, systemImage: "pencil")
            }

            if project.canAssign {
                Button {
                    showAssignSheet = true
                } label: {
                    Label(L10n.projectDueAssign, systemImage: "person.fill.badge.plus")
                }
            }

            Divider()

            Button(role: .destructive) {
                Task { await viewModel.deleteDue(due) }
            } label: {
                Label(L10n.delete, systemImage: "trash")
            }
        }
    }

    // MARK: - Due Date Label

    private var dueDateLabel: some View {
        Group {
            if due.isCompleted {
                Text(L10n.projectDueCompleted)
                    .foregroundStyle(.green)
            } else if due.isOverdue {
                Text(L10n.projectDueOverdue)
                    .foregroundStyle(.red)
            } else if due.daysRemaining == 0 {
                Text(L10n.projectDueToday)
                    .foregroundStyle(.orange)
            } else {
                Text(L10n.projectDueDaysLeft(due.daysRemaining))
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 11, weight: .medium))
    }

    // MARK: - Assignee

    private var assigneeView: some View {
        Button {
            if project.canAssign {
                showAssignSheet = true
            }
        } label: {
            if due.isAssigned {
                VStack(spacing: 2) {
                    // Overlapping avatar stack
                    HStack(spacing: -8) {
                        ForEach(Array(due.assigneeEmojis.prefix(3).enumerated()), id: \.offset) { idx, emoji in
                            Text(emoji)
                                .font(.system(size: due.assigneeEmojis.count > 1 ? 14 : 18))
                                .frame(width: due.assigneeEmojis.count > 1 ? 24 : 32, height: due.assigneeEmojis.count > 1 ? 24 : 32)
                                .background(
                                    Circle().fill(Color(.tertiarySystemFill))
                                )
                                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                                .zIndex(Double(3 - idx))
                        }
                    }
                    if due.assigneeNames.count == 1, let name = due.assigneeNames.first {
                        Text(name)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(width: 40)
                    } else {
                        Text("\(due.assigneeNames.count)人")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack(spacing: 2) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text(L10n.projectDueUnassigned)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!project.canAssign)
    }
}
