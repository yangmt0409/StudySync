import SwiftUI
import FirebaseAuth

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    private var auth: AuthService { .shared }

    @State private var friendCode = ""
    @State private var isSearching = false
    @State private var foundUser: UserProfile?
    @State private var requestSent = false
    @State private var errorMessage: String?
    // #4 Anti-spam: track user IDs that have been sent requests successfully
    @State private var sentToUserIds: Set<String> = []
    // #12 Copy feedback toast
    @State private var showCopiedToast = false

    var body: some View {
        VStack(spacing: SSSpacing.xxxl) {
            // Header
            VStack(spacing: SSSpacing.md) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 44))
                    .foregroundStyle(SSColor.travel)
                    .padding(.top, SSSpacing.xxl)

                Text(L10n.socialAddFriend)
                    .font(.system(size: 20, weight: .bold))

                Text(L10n.socialAddFriendDesc)
                    .font(SSFont.secondary)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // My friend code
            if let profile = auth.userProfile {
                VStack(spacing: SSSpacing.sm) {
                    Text(L10n.socialMyCode)
                        .font(SSFont.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: SSSpacing.md) {
                        Text(profile.friendCode)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(SSColor.brand)

                        Button {
                            UIPasteboard.general.string = profile.friendCode
                            HapticEngine.shared.lightImpact()
                            // #12 Copy feedback
                            withAnimation { showCopiedToast = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation { showCopiedToast = false }
                            }
                        } label: {
                            Image(systemName: "doc.on.doc.fill")
                                .font(SSFont.body)
                                .foregroundStyle(SSColor.brand)
                        }
                    }
                }
                .padding(.vertical, SSSpacing.lg)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                        .fill(SSColor.brand.opacity(SSOpacity.shadow))
                )
                .padding(.horizontal, SSSpacing.xxxl)
            }

            // Enter friend's code
            VStack(spacing: SSSpacing.lg) {
                Text(L10n.socialEnterCode)
                    .font(SSFont.chipLabel)

                TextField("XXXXXX", text: $friendCode)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 60)
                    .onChange(of: friendCode) { _, newValue in
                        friendCode = String(newValue.uppercased().prefix(6))
                        // Reset state when code changes (but keep sentToUserIds for anti-spam)
                        foundUser = nil
                        requestSent = false
                        errorMessage = nil
                    }
            }
            .padding(.horizontal, SSSpacing.xxxl)

            // Search button
            Button {
                Task { await searchFriend() }
            } label: {
                if isSearching {
                    ProgressView().tint(.white)
                } else {
                    Text(L10n.socialSearch)
                        .font(SSFont.bodySemibold)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SSSpacing.lgXl)
            .background(
                RoundedRectangle(cornerRadius: SSRadius.fieldCard, style: .continuous)
                    .fill(friendCode.count == 6
                          ? SSColor.travel.gradient
                          : Color.gray.gradient)
            )
            .padding(.horizontal, SSSpacing.xxxl)
            .disabled(friendCode.count != 6 || isSearching)

            // Result
            if let user = foundUser {
                foundUserCard(user)
            }

            if requestSent {
                HStack(spacing: SSSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(L10n.socialRequestSent)
                        .font(SSFont.bodySmallMedium)
                        .foregroundStyle(.green)
                }
                .padding(.top, SSSpacing.md)
            }

            if let error = errorMessage {
                Text(error)
                    .font(SSFont.secondary)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SSSpacing.xxxl)
            }

            Spacer()
        }
        .navigationTitle(L10n.socialAddFriend)
        .navigationBarTitleDisplayMode(.inline)
        .dismissKeyboardToolbar()
        // #12 Copied toast overlay
        .overlay(alignment: .top) {
            if showCopiedToast {
                HStack(spacing: SSSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(L10n.codeCopied)
                        .font(SSFont.caption)
                }
                .padding(.horizontal, SSSpacing.xl)
                .padding(.vertical, SSSpacing.md)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, SSSpacing.md)
            }
        }
    }

    // MARK: - Found User Card

    private func foundUserCard(_ user: UserProfile) -> some View {
        let alreadySent = sentToUserIds.contains(user.id)
        return HStack(spacing: SSSpacing.lgXl) {
            Text(user.avatarEmoji)
                .font(.system(size: 36))

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(SSFont.bodySemibold)
                Text(user.friendCode)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if alreadySent {
                // #4 Anti-spam: show disabled state if already sent successfully
                Text(L10n.socialRequestSent)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.green)
            } else {
                Button {
                    Task { await sendRequest(to: user) }
                } label: {
                    Text(requestSent ? L10n.socialRequestSent : L10n.socialSendRequest)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, SSSpacing.xl)
                        .padding(.vertical, SSSpacing.md)
                        .background(Capsule().fill(
                            requestSent ? Color.gray.gradient : SSColor.brand.gradient
                        ))
                }
                .disabled(requestSent)
            }
        }
        .padding(SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, SSSpacing.xxxl)
    }

    // MARK: - Actions

    private func searchFriend() async {
        isSearching = true
        errorMessage = nil

        let user = await FirestoreService.shared.findUserByFriendCode(friendCode)

        if let user {
            if user.id == auth.currentUser?.uid {
                errorMessage = L10n.socialCannotAddSelf
            } else {
                foundUser = user
            }
        } else {
            errorMessage = L10n.socialUserNotFound
        }

        isSearching = false
    }

    private func sendRequest(to user: UserProfile) async {
        guard let profile = auth.userProfile else { return }

        // #4 Anti-spam: prevent re-sending if already sent successfully
        guard !sentToUserIds.contains(user.id) else {
            errorMessage = L10n.friendRequestAlreadySent
            return
        }

        let success = await FirestoreService.shared.sendFriendRequest(from: profile, to: user.id)
        if success {
            requestSent = true
            sentToUserIds.insert(user.id) // #4 Track successful sends
            HapticEngine.shared.celebrationBurst()
        } else {
            // #4 Allow retry on failure — don't set requestSent
            errorMessage = L10n.socialRequestFailed
        }
    }
}

#Preview {
    NavigationStack {
        AddFriendView()
    }
}
