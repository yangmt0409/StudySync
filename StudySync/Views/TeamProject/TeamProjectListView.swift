import SwiftUI

struct TeamProjectListView: View {
    @State private var viewModel = TeamProjectViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            SSColor.backgroundPrimary
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Pending invites
                    if !viewModel.projectInvites.isEmpty {
                        invitesSection
                    }

                    // My projects
                    if viewModel.myProjects.isEmpty && viewModel.projectInvites.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(viewModel.myProjects.enumerated()), id: \.element.id) { index, project in
                            NavigationLink {
                            ProjectDetailView(project: project, viewModel: viewModel)
                        } label: {
                            ProjectRowCard(project: project)
                        }
                        .buttonStyle(.plain)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)
                        .animation(
                            .spring(duration: 0.5).delay(Double(index) * 0.08),
                            value: hasAppeared
                        )
                    }
                }

                // Archived projects link
                if !viewModel.myProjects.isEmpty {
                    Button {
                        viewModel.showingArchivedProjects = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "archivebox")
                                .font(.system(size: 14))
                            Text(L10n.projectArchivedProjects)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        }
        .navigationTitle(L10n.projectTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        viewModel.tryCreateProject()
                        HapticEngine.shared.lightImpact()
                    } label: {
                        Label(L10n.projectCreate, systemImage: "plus.rectangle.fill")
                    }

                    Button {
                        viewModel.showingJoinProject = true
                        HapticEngine.shared.lightImpact()
                    } label: {
                        Label(L10n.projectJoin, systemImage: "person.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(SSColor.brand)
                }
            }
        }
        .sheet(isPresented: $viewModel.showingCreateProject) {
            CreateProjectView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $viewModel.showingJoinProject) {
            JoinProjectView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingArchivedProjects) {
            NavigationStack {
                ArchivedProjectsView(viewModel: viewModel)
            }
        }
        .task {
            await viewModel.loadProjects()
            withAnimation(.spring(duration: 0.5)) { hasAppeared = true }
        }
        .refreshable {
            await viewModel.loadProjects()
        }
        .overlay {
            if viewModel.isLoading && viewModel.myProjects.isEmpty {
                ProgressView()
            }
        }
        // #5 Error toast
        .overlay(alignment: .bottom) {
            if let error = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(SSFont.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, SSSpacing.xl)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, SSSpacing.xxl)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { viewModel.errorMessage = nil }
                    }
                }
            }
        }
        .animation(.spring(duration: 0.3), value: viewModel.errorMessage == nil)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)

            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color(hex: "#5B7FFF").opacity(0.4))

            Text(L10n.projectEmpty)
                .font(.system(size: 18, weight: .semibold))

            Text(L10n.projectEmptyDesc)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            HStack(spacing: 12) {
                Button {
                    viewModel.tryCreateProject()
                    HapticEngine.shared.lightImpact()
                } label: {
                    Label(L10n.projectCreate, systemImage: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color(hex: "#5B7FFF").gradient))
                }

                Button {
                    viewModel.showingJoinProject = true
                    HapticEngine.shared.lightImpact()
                } label: {
                    Label(L10n.projectJoin, systemImage: "person.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "#5B7FFF"))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().stroke(Color(hex: "#5B7FFF"), lineWidth: 1.5)
                        )
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Invites Section

    private var invitesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.projectInvites)
                    .font(SSFont.bodySemibold)
                Text("\(viewModel.projectInvites.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.red))
            }

            ForEach(Array(viewModel.projectInvites.enumerated()), id: \.element.id) { index, invite in
                ProjectInviteCard(invite: invite, viewModel: viewModel)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 15)
                    .animation(.spring(duration: 0.5).delay(Double(index) * 0.08), value: hasAppeared)
            }
        }
    }
}

// MARK: - Project Row Card

struct ProjectRowCard: View {
    let project: TeamProject

    private var color: Color { Color(hex: project.colorHex) }

    var body: some View {
        HStack(spacing: 14) {
            Text(project.emoji)
                .font(.system(size: 32))
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    // Member count
                    HStack(spacing: 3) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 11))
                        Text(L10n.projectMemberCount(project.memberCount))
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.secondary)

                    // Project code
                    Text(project.projectCode)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(color)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Project Invite Card

struct ProjectInviteCard: View {
    let invite: ProjectInvite
    let viewModel: TeamProjectViewModel
    @State private var isAccepting = false
    @State private var isRejecting = false

    var body: some View {
        HStack(spacing: 12) {
            Text(invite.projectEmoji)
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 2) {
                Text(invite.projectName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                Text(L10n.projectInviteFrom(invite.inviterName))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                HapticEngine.shared.lightImpact()
                isAccepting = true
                Task {
                    let ok = await viewModel.acceptInvite(invite)
                    isAccepting = false
                    if ok {
                        HapticEngine.shared.success()
                    } else {
                        HapticEngine.shared.error()
                    }
                }
            } label: {
                if isAccepting {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                } else {
                    Text(L10n.projectInviteAccept)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
            }
            .background(Capsule().fill(SSColor.brand))
            .disabled(isAccepting || isRejecting)
            .accessibilityLabel(L10n.projectInviteAccept)

            Button {
                HapticEngine.shared.selection()
                isRejecting = true
                Task {
                    await viewModel.rejectInvite(invite)
                    isRejecting = false
                }
            } label: {
                if isRejecting {
                    ProgressView()
                        .controlSize(.small)
                        .padding(8)
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
            }
            .background(Circle().fill(SSColor.fillTertiary))
            .disabled(isAccepting || isRejecting)
            .accessibilityLabel(L10n.projectInviteReject)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SSColor.brand.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        TeamProjectListView()
    }
}
