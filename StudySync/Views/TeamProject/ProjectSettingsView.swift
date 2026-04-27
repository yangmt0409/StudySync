import SwiftUI

struct ProjectSettingsView: View {
    let viewModel: TeamProjectViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showArchiveAlert = false
    @State private var showLeaveAlert = false
    @State private var showDeleteAlert = false
    @State private var codeCopied = false

    private var project: TeamProject? { viewModel.currentProject }
    private var isOwner: Bool {
        guard let uid = viewModel.currentUid else { return false }
        return viewModel.isOwner(uid: uid)
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: SSSpacing.xl) {
                    if let project {
                        // Project code
                        codeSection(project)

                        // Members
                        membersSection(project)

                        // Invite
                        NavigationLink {
                            InviteFriendToProjectView(viewModel: viewModel)
                        } label: {
                            menuRow(icon: "person.badge.plus", color: "#4ECDC4",
                                    title: L10n.projectInviteFriend, showChevron: true)
                        }

                        // Actions
                        actionsSection(project)
                    }
                }
                .padding(.horizontal, SSSpacing.xl)
                .padding(.top, SSSpacing.md)
                .padding(.bottom, SSSpacing.xxl)
            }
        }
        .navigationTitle(L10n.projectSettings)
        .navigationBarTitleDisplayMode(.inline)
        .alert(L10n.projectArchive, isPresented: $showArchiveAlert) {
            Button(L10n.cancel, role: .cancel) {}
            Button(L10n.projectArchive, role: .destructive) {
                Task {
                    await viewModel.archiveProject()
                    dismiss()
                }
            }
        } message: {
            Text(L10n.projectArchiveConfirm)
        }
        .alert(L10n.projectLeave, isPresented: $showLeaveAlert) {
            Button(L10n.cancel, role: .cancel) {}
            Button(L10n.projectLeave, role: .destructive) {
                Task {
                    await viewModel.leaveProject()
                    dismiss()
                }
            }
        } message: {
            Text(L10n.projectLeaveConfirm)
        }
        .alert(L10n.projectDelete, isPresented: $showDeleteAlert) {
            Button(L10n.cancel, role: .cancel) {}
            Button(L10n.delete, role: .destructive) {
                Task {
                    await viewModel.deleteProject()
                    dismiss()
                }
            }
        } message: {
            Text(L10n.projectDeleteConfirm)
        }
    }

    // MARK: - Code Section

    private func codeSection(_ project: TeamProject) -> some View {
        VStack(spacing: SSSpacing.lg) {
            Text(L10n.projectCode)
                .font(SSFont.caption)
                .foregroundStyle(.secondary)

            Text(project.projectCode)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: project.colorHex))

            // QR code for scan-to-join
            if let qrImage = QRCodeGenerator.image(from: "studysync://project/\(project.projectCode)") {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .padding(SSSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.fieldCard, style: .continuous)
                            .fill(Color.white)
                    )
            }

            Button {
                UIPasteboard.general.string = project.projectCode
                HapticEngine.shared.lightImpact()
                withAnimation { codeCopied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { codeCopied = false }
                }
            } label: {
                HStack(spacing: SSSpacing.sm) {
                    Image(systemName: codeCopied ? "checkmark" : "doc.on.doc")
                        .font(SSFont.caption)
                    Text(codeCopied ? L10n.projectCodeCopied : L10n.projectCopyCode)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(codeCopied ? .green : SSColor.brand)
                .padding(.horizontal, SSSpacing.xl)
                .padding(.vertical, SSSpacing.md)
                .background(
                    Capsule().fill(SSColor.brand.opacity(0.1))
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(SSSpacing.xxl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Members

    private func membersSection(_ project: TeamProject) -> some View {
        VStack(alignment: .leading, spacing: SSSpacing.lg) {
            HStack {
                Text(L10n.projectMembers)
                    .font(SSFont.bodySemibold)
                Spacer()
                Text(L10n.projectMemberCount(project.memberCount))
                    .font(SSFont.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(project.memberProfiles.enumerated()), id: \.element.id) { index, member in
                    HStack(spacing: SSSpacing.lg) {
                        Text(member.avatarEmoji)
                            .font(.system(size: 22))
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Color(.tertiarySystemFill)))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.displayName)
                                .font(SSFont.bodySmallMedium)
                            Text(member.role == .owner ? L10n.projectOwner : L10n.projectMember)
                                .font(SSFont.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if member.role == .owner {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.vertical, SSSpacing.mdLg)
                    .padding(.horizontal, SSSpacing.xl)

                    if index < project.memberProfiles.count - 1 {
                        Divider().padding(.leading, 66)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    // MARK: - Actions

    private func actionsSection(_ project: TeamProject) -> some View {
        VStack(spacing: SSSpacing.mdLg) {
            // Archive (owner only)
            if isOwner {
                Button {
                    showArchiveAlert = true
                } label: {
                    HStack {
                        Image(systemName: "archivebox")
                        Text(L10n.projectArchive)
                    }
                    .font(SSFont.bodySmallMedium)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SSSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.fieldCard, style: .continuous)
                            .fill(Color.orange.opacity(0.1))
                    )
                }
            }

            // Leave (non-owner)
            if !isOwner {
                Button {
                    showLeaveAlert = true
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text(L10n.projectLeave)
                    }
                    .font(SSFont.bodySmallMedium)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SSSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.fieldCard, style: .continuous)
                            .fill(Color.red.opacity(0.1))
                    )
                }
            }

            // Delete (owner only)
            if isOwner {
                Button {
                    showDeleteAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text(L10n.projectDelete)
                    }
                    .font(SSFont.bodySmallMedium)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SSSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.fieldCard, style: .continuous)
                            .fill(Color.red.opacity(0.1))
                    )
                }
            }
        }
    }

    // MARK: - Menu Row

    private func menuRow(icon: String, color: String, title: String, showChevron: Bool) -> some View {
        HStack(spacing: SSSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color(hex: color))
                .frame(width: 28)

            Text(title)
                .font(SSFont.bodyMedium)
                .foregroundStyle(.primary)

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}
