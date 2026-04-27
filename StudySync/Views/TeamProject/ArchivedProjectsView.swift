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
                    VStack(spacing: SSSpacing.xl) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text(L10n.projectArchivedProjects)
                            .font(SSFont.bodyMedium)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: SSSpacing.lg) {
                            ForEach(viewModel.archivedProjects) { project in
                                NavigationLink {
                                    ProjectDetailView(project: project, viewModel: viewModel)
                                } label: {
                                    HStack(spacing: SSSpacing.lgXl) {
                                        Text(project.emoji)
                                            .font(SSFont.emojiLarge)

                                        VStack(alignment: .leading, spacing: SSSpacing.xxs) {
                                            Text(project.name)
                                                .font(SSFont.bodySmallMedium)
                                                .foregroundStyle(.secondary)

                                            HStack(spacing: SSSpacing.md) {
                                                Text(L10n.projectMemberCount(project.memberCount))
                                                    .font(SSFont.footnote)
                                                    .foregroundStyle(.tertiary)

                                                if let archivedAt = project.archivedAt {
                                                    Text(archivedAt.formattedShort)
                                                        .font(SSFont.footnote)
                                                        .foregroundStyle(.tertiary)
                                                }
                                            }
                                        }

                                        Spacer()

                                        Text(L10n.projectArchived)
                                            .font(SSFont.badge)
                                            .foregroundStyle(.orange)
                                            .padding(.horizontal, SSSpacing.md)
                                            .padding(.vertical, 3)
                                            .background(
                                                Capsule().fill(Color.orange.opacity(0.1))
                                            )
                                    }
                                    .padding(SSSpacing.lgXl)
                                    .background(
                                        RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                                            .fill(Color(.secondarySystemGroupedBackground))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, SSSpacing.xl)
                        .padding(.top, SSSpacing.md)
                        .padding(.bottom, SSSpacing.xxl)
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
