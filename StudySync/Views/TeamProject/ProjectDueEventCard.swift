import SwiftUI

/// Card displayed in CalendarFeedView for project dues
struct ProjectDueEventCard: View {
    let due: ProjectDue
    let projectName: String
    let projectColorHex: String
    let onToggleComplete: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var color: Color { Color(hex: projectColorHex) }
    private var priorityColor: Color { Color(hex: due.priority.colorHex) }

    var body: some View {
        HStack(spacing: 12) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(color.gradient)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                // Project badge
                HStack(spacing: 4) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 9))
                    Text(projectName)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(color.opacity(0.12))
                )

                // Title
                HStack(spacing: 6) {
                    Text(due.emoji)
                        .font(.system(size: 14))
                    Text(due.title)
                        .font(.system(size: 15, weight: .semibold))
                        .strikethrough(due.isCompleted, color: .secondary)
                        .foregroundStyle(due.isCompleted ? .secondary : .primary)
                        .lineLimit(1)
                }

                // Bottom row: priority + assignee + time
                HStack(spacing: 8) {
                    // Priority
                    HStack(spacing: 2) {
                        Image(systemName: due.priority.icon)
                            .font(.system(size: 9))
                        Text(due.priority.displayName)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(priorityColor)

                    // Assignees
                    if due.isAssigned {
                        HStack(spacing: 3) {
                            HStack(spacing: -2) {
                                ForEach(Array(due.assigneeEmojis.prefix(3).enumerated()), id: \.offset) { _, emoji in
                                    Text(emoji)
                                        .font(.system(size: 11))
                                }
                            }
                            if due.assigneeNames.count == 1, let name = due.assigneeNames.first {
                                Text(name)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(due.assigneeNames.count)人")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()

                    // Due status
                    if due.isCompleted {
                        Label(L10n.projectDueCompleted, systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.green)
                    } else if due.isOverdue {
                        Label(L10n.projectDueOverdue, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.red)
                    } else if due.daysRemaining == 0 {
                        Text(L10n.projectDueToday)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.orange)
                    } else {
                        Text(due.dueDate.formattedTime(in: .current))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Toggle
            Button(action: onToggleComplete) {
                Image(systemName: due.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(due.isCompleted ? .green : color)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    due.isOverdue ? Color.red.opacity(0.25) :
                    due.isUrgent ? Color.orange.opacity(0.25) :
                    color.opacity(colorScheme == .dark ? 0.15 : 0.1),
                    lineWidth: 1
                )
        )
        .opacity(due.isCompleted ? 0.7 : 1)
    }
}

#Preview {
    VStack(spacing: 12) {
        ProjectDueEventCard(
            due: ProjectDue(
                title: "Write Introduction",
                emoji: "📝",
                dueDate: Date().addingTimeInterval(86400),
                createdBy: "uid1",
                creatorName: "James",
                assignedTo: ["uid2"],
                assigneeNames: ["Alice"],
                assigneeEmojis: ["🐱"],
                priority: .high
            ),
            projectName: "CS 341 Project",
            projectColorHex: "#5B7FFF",
            onToggleComplete: {}
        )

        ProjectDueEventCard(
            due: ProjectDue(
                title: "Submit Final Report",
                emoji: "📋",
                dueDate: Date().addingTimeInterval(-86400),
                createdBy: "uid1",
                creatorName: "James",
                priority: .medium
            ),
            projectName: "MATH 235",
            projectColorHex: "#FF6B6B",
            onToggleComplete: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
