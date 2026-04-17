import SwiftUI

struct AssignMemberSheet: View {
    let due: ProjectDue
    let project: TeamProject
    let viewModel: TeamProjectViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIds: Set<String>

    init(due: ProjectDue, project: TeamProject, viewModel: TeamProjectViewModel) {
        self.due = due
        self.project = project
        self.viewModel = viewModel
        _selectedIds = State(initialValue: Set(due.assignedTo))
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(project.memberProfiles) { member in
                    let selected = selectedIds.contains(member.id)
                    Button {
                        if selected {
                            selectedIds.remove(member.id)
                        } else {
                            selectedIds.insert(member.id)
                        }
                        HapticEngine.shared.selection()
                    } label: {
                        HStack(spacing: 12) {
                            Text(member.avatarEmoji)
                                .font(.system(size: 24))
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle().fill(Color(.tertiarySystemFill))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.primary)
                                if member.role == .owner {
                                    Text(L10n.projectOwner)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if selected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color(hex: "#5B7FFF"))
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.projectDueAssign)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.done) {
                        save()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let members = project.memberProfiles.filter { selectedIds.contains($0.id) }
        Task {
            await viewModel.assignDue(due, to: members)
            HapticEngine.shared.lightImpact()
            dismiss()
        }
    }
}
