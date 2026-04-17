import SwiftUI

struct ArchivedProjectsView: View {
    let viewModel: TeamProjectViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            Group {
                if viewModel.archivedProjects.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text(L10n.projectArchivedProjects)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(viewModel.archivedProjects) { project in
                                NavigationLink {
                                    ProjectDetailView(project: project, viewModel: viewModel)
                                } label: {
                                    HStack(spacing: 14) {
                                        Text(project.emoji)
                                            .font(.system(size: 28))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(project.name)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundStyle(.secondary)

                                            HStack(spacing: 8) {
                                                Text(L10n.projectMemberCount(project.memberCount))
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(.tertiary)

                                                if let archivedAt = project.archivedAt {
                                                    Text(archivedAt.formattedShort)
                                                        .font(.system(size: 12))
                                                        .foregroundStyle(.tertiary)
                                                }
                                            }
                                        }

                                        Spacer()

                                        Text(L10n.projectArchived)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.orange)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(
                                                Capsule().fill(Color.orange.opacity(0.1))
                                            )
                                    }
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color(.secondarySystemGroupedBackground))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .navigationTitle(L10n.projectArchivedProjects)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L10n.done) { dismiss() }
                    .fontWeight(.semibold)
            }
        }
        .task {
            await viewModel.loadArchivedProjects()
        }
    }
}
