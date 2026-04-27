import SwiftUI
import SwiftData
import FirebaseAuth

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Query private var unlockedSpaceItems: [StudySpaceItem]
    private var auth: AuthService { .shared }

    @State private var displayName: String = ""
    @State private var avatarEmoji: String = "😊"
    @State private var showcaseBadges: [String] = []
    @State private var showcaseDecorations: [String] = []
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var showUnsavedAlert = false

    // Track initial values for unsaved changes detection
    @State private var initialName: String = ""
    @State private var initialEmoji: String = "😊"
    @State private var initialBadges: [String] = []
    @State private var initialDecorations: [String] = []

    private var hasUnsavedChanges: Bool {
        displayName != initialName || avatarEmoji != initialEmoji || showcaseBadges != initialBadges || showcaseDecorations != initialDecorations
    }

    private var unlockedItemIds: Set<String> {
        Set(unlockedSpaceItems.map(\.itemId))
    }

    private let emojiOptions = [
        "😊", "😎", "🤓", "🧑‍💻", "👩‍🎓", "👨‍🎓",
        "🦊", "🐱", "🐰", "🐼", "🦄", "🐸",
        "🌟", "🔥", "💎", "🎯", "🚀", "🎨"
    ]

    var body: some View {
        Form {
            // Avatar
            Section {
                LazyVGrid(columns: iPadGridColumns(iPhone: 6, spacing: SSSpacing.md, sizeClass: hSizeClass), spacing: SSSpacing.lg) {
                    ForEach(emojiOptions, id: \.self) { emoji in
                        Button {
                            avatarEmoji = emoji
                            HapticEngine.shared.selection()
                        } label: {
                            Text(emoji)
                                .font(.system(size: 28))
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                                .background(
                                    Circle()
                                        .fill(avatarEmoji == emoji
                                              ? SSColor.brand.opacity(SSOpacity.lightTint)
                                              : Color(.tertiarySystemFill))
                                )
                                .overlay(
                                    Circle()
                                        .stroke(avatarEmoji == emoji ? SSColor.brand : .clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, SSSpacing.xs)
            } header: {
                Text(L10n.socialAvatar)
            }

            // Name
            Section {
                TextField(L10n.socialDisplayName, text: $displayName)
            } header: {
                Text(L10n.socialDisplayName)
            }

            // Friend Code (read only)
            if let profile = auth.userProfile {
                Section {
                    HStack {
                        Text(profile.friendCode)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                        Spacer()
                        Button {
                            UIPasteboard.general.string = profile.friendCode
                            HapticEngine.shared.lightImpact()
                        } label: {
                            Label(L10n.socialCopy, systemImage: "doc.on.doc")
                                .font(SSFont.secondary)
                        }
                    }
                } header: {
                    Text(L10n.socialFriendCode)
                } footer: {
                    Text(L10n.socialFriendCodeDesc)
                }
            }

            // Showcase Badges
            if let profile = auth.userProfile {
                Section {
                    let earnedBadges = Badge.earned(from: profile.badges)
                    if earnedBadges.isEmpty {
                        VStack(spacing: SSSpacing.sm) {
                            Text(L10n.socialNoEarnedBadges)
                                .font(SSFont.chipLabel)
                                .foregroundStyle(.secondary)
                            Text(L10n.socialNoEarnedBadgesDesc)
                                .font(SSFont.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SSSpacing.md)
                    } else {
                        // Current showcase
                        if !showcaseBadges.isEmpty {
                            HStack(spacing: SSSpacing.lg) {
                                ForEach(showcaseBadges, id: \.self) { badgeId in
                                    if let badge = Badge.badge(for: badgeId) {
                                        VStack(spacing: SSSpacing.xs) {
                                            Text(badge.emoji)
                                                .font(.system(size: 28))
                                                .frame(width: 48, height: 48)
                                                .background(
                                                    Circle()
                                                        .fill(badge.color.opacity(SSOpacity.lightTint))
                                                )
                                                .overlay(
                                                    Circle()
                                                        .stroke(badge.color.opacity(SSOpacity.disabled), lineWidth: 1.5)
                                                )
                                            Text(badge.name)
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, SSSpacing.xs)
                        }

                        // Badge picker grid
                        LazyVGrid(columns: iPadGridColumns(iPhone: 5, spacing: SSSpacing.md, sizeClass: hSizeClass), spacing: SSSpacing.mdLg) {
                            ForEach(earnedBadges) { badge in
                                Button {
                                    toggleShowcaseBadge(badge.id)
                                    HapticEngine.shared.selection()
                                } label: {
                                    VStack(spacing: 2) {
                                        Text(badge.emoji)
                                            .font(.system(size: 24))
                                            .frame(width: 44, height: 44)
                                            .background(
                                                Circle()
                                                    .fill(showcaseBadges.contains(badge.id)
                                                          ? badge.color.opacity(0.2)
                                                          : Color(.tertiarySystemFill))
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(showcaseBadges.contains(badge.id)
                                                            ? badge.color : .clear, lineWidth: 2)
                                            )
                                        Text(badge.name)
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .padding(.vertical, SSSpacing.xs)
                    }
                } header: {
                    Text(L10n.socialShowcaseBadges)
                } footer: {
                    Text(L10n.socialShowcaseBadgesDesc)
                }
            }

            // Showcase Decorations (desk items)
            Section {
                let unlockedDecorations = StudySpaceItem.catalog.filter { unlockedItemIds.contains($0.id) }
                if unlockedDecorations.isEmpty {
                    VStack(spacing: SSSpacing.sm) {
                        Text(L10n.profileNoDecorations)
                            .font(SSFont.chipLabel)
                            .foregroundStyle(.secondary)
                        Text(L10n.profileNoDecorationsDesc)
                            .font(SSFont.footnote)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SSSpacing.md)
                } else {
                    // Current showcase preview — mini desk
                    if !showcaseDecorations.isEmpty {
                        HStack(spacing: SSSpacing.lgXl) {
                            ForEach(showcaseDecorations, id: \.self) { itemId in
                                if let item = StudySpaceItem.catalog.first(where: { $0.id == itemId }) {
                                    VStack(spacing: SSSpacing.xs) {
                                        Text(item.emoji)
                                            .font(.system(size: 28))
                                            .frame(width: 48, height: 48)
                                            .background(
                                                RoundedRectangle(cornerRadius: SSRadius.fieldCard)
                                                    .fill(Color(hex: "#F59E0B").opacity(SSOpacity.tagBackground))
                                            )
                                        Text(item.name)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SSSpacing.xs)
                    }

                    // Decoration picker grid
                    LazyVGrid(columns: iPadGridColumns(iPhone: 5, spacing: SSSpacing.md, sizeClass: hSizeClass), spacing: SSSpacing.mdLg) {
                        ForEach(unlockedDecorations) { item in
                            Button {
                                toggleShowcaseDecoration(item.id)
                                HapticEngine.shared.selection()
                            } label: {
                                VStack(spacing: 2) {
                                    Text(item.emoji)
                                        .font(.system(size: 24))
                                        .frame(width: 44, height: 44)
                                        .background(
                                            RoundedRectangle(cornerRadius: SSRadius.small)
                                                .fill(showcaseDecorations.contains(item.id)
                                                      ? Color(hex: "#F59E0B").opacity(0.2)
                                                      : Color(.tertiarySystemFill))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: SSRadius.small)
                                                .stroke(showcaseDecorations.contains(item.id)
                                                        ? Color(hex: "#F59E0B") : .clear, lineWidth: 2)
                                        )
                                    Text(item.name)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, SSSpacing.xs)
                }
            } header: {
                Text(L10n.profileShowcaseDecorations)
            } footer: {
                Text(L10n.profileShowcaseDecorationsDesc)
            }

            // Account info
            Section {
                if let email = auth.currentUser?.email {
                    HStack {
                        Text(L10n.socialEmail)
                        Spacer()
                        Text(email).foregroundStyle(.secondary)
                    }
                }
                if let created = auth.userProfile?.createdAt {
                    HStack {
                        Text(L10n.socialJoined)
                        Spacer()
                        Text(created.formattedChinese).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(L10n.socialAccountInfo)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(L10n.socialEditProfile)
        .navigationBarTitleDisplayMode(.inline)
        .dismissKeyboardToolbar()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.cancel) {
                    if hasUnsavedChanges {
                        showUnsavedAlert = true
                    } else {
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    saveProfile()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text(L10n.save)
                            .font(SSFont.bodySemibold)
                    }
                }
                .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            if let profile = auth.userProfile {
                displayName = profile.displayName
                avatarEmoji = profile.avatarEmoji
                showcaseBadges = profile.showcaseBadges
                showcaseDecorations = profile.showcaseDecorations
                // #10 Track initial values
                initialName = profile.displayName
                initialEmoji = profile.avatarEmoji
                initialBadges = profile.showcaseBadges
                initialDecorations = profile.showcaseDecorations
            }
        }
        // #10 Unsaved changes warning
        .alert(L10n.unsavedChangesTitle, isPresented: $showUnsavedAlert) {
            Button(L10n.discardChanges, role: .destructive) { dismiss() }
            Button(L10n.continueEditing, role: .cancel) {}
        } message: {
            Text(L10n.unsavedChangesMessage)
        }
        // #2 Save success toast
        .overlay(alignment: .bottom) {
            if showSaveSuccess {
                HStack(spacing: SSSpacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(L10n.profileSaved)
                        .font(SSFont.caption)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, SSSpacing.xl)
                .padding(.vertical, SSSpacing.mdLg)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, SSSpacing.xxl)
            }
        }
        .animation(.spring(duration: 0.3), value: showSaveSuccess)
    }

    private func toggleShowcaseBadge(_ badgeId: String) {
        if let index = showcaseBadges.firstIndex(of: badgeId) {
            showcaseBadges.remove(at: index)
        } else if showcaseBadges.count < 3 {
            showcaseBadges.append(badgeId)
        }
    }

    private func toggleShowcaseDecoration(_ itemId: String) {
        if let index = showcaseDecorations.firstIndex(of: itemId) {
            showcaseDecorations.remove(at: index)
        } else if showcaseDecorations.count < 5 {
            showcaseDecorations.append(itemId)
        }
    }

    private func saveProfile() {
        guard let uid = auth.currentUser?.uid, !isSaving else { return }
        isSaving = true
        Task {
            await FirestoreService.shared.updateProfile(uid: uid, fields: [
                "displayName": displayName.trimmingCharacters(in: .whitespaces),
                "avatarEmoji": avatarEmoji,
                "showcaseBadges": showcaseBadges,
                "showcaseDecorations": showcaseDecorations
            ])
            auth.userProfile?.displayName = displayName
            auth.userProfile?.avatarEmoji = avatarEmoji
            auth.userProfile?.showcaseBadges = showcaseBadges
            auth.userProfile?.showcaseDecorations = showcaseDecorations
            isSaving = false
            // Update initial values so unsaved detection is reset
            initialName = displayName
            initialEmoji = avatarEmoji
            initialBadges = showcaseBadges
            initialDecorations = showcaseDecorations
            HapticEngine.shared.success()
            // #2 Show success toast then dismiss
            withAnimation { showSaveSuccess = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                dismiss()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
