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
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 44))
                    .foregroundStyle(Color(hex: "#4ECDC4"))
                    .padding(.top, 20)

                Text(L10n.socialAddFriend)
                    .font(.system(size: 20, weight: .bold))

                Text(L10n.socialAddFriendDesc)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // My friend code
            if let profile = auth.userProfile {
                VStack(spacing: 6) {
                    Text(L10n.socialMyCode)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Text(profile.friendCode)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: "#5B7FFF"))

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
                                .font(.system(size: 16))
                                .foregroundStyle(Color(hex: "#5B7FFF"))
                        }
                    }
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: "#5B7FFF").opacity(0.08))
                )
                .padding(.horizontal, 24)
            }

            // Enter friend's code
            VStack(spacing: 12) {
                Text(L10n.socialEnterCode)
                    .font(.system(size: 14, weight: .medium))

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
            .padding(.horizontal, 24)

            // Search button
            Button {
                Task { await searchFriend() }
            } label: {
                if isSearching {
                    ProgressView().tint(.white)
                } else {
                    Text(L10n.socialSearch)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(friendCode.count == 6
                          ? Color(hex: "#4ECDC4").gradient
                          : Color.gray.gradient)
            )
            .padding(.horizontal, 24)
            .disabled(friendCode.count != 6 || isSearching)

            // Result
            if let user = foundUser {
                foundUserCard(user)
            }

            if requestSent {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(L10n.socialRequestSent)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.green)
                }
                .padding(.top, 8)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .navigationTitle(L10n.socialAddFriend)
        .navigationBarTitleDisplayMode(.inline)
        // #12 Copied toast overlay
        .overlay(alignment: .top) {
            if showCopiedToast {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(L10n.codeCopied)
                        .font(SSFont.caption)
                }
                .padding(.horizontal, SSSpacing.xl)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Found User Card

    private func foundUserCard(_ user: UserProfile) -> some View {
        let alreadySent = sentToUserIds.contains(user.id)
        return HStack(spacing: 14) {
            Text(user.avatarEmoji)
                .font(.system(size: 36))

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.system(size: 16, weight: .semibold))
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
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(
                            requestSent ? Color.gray.gradient : Color(hex: "#5B7FFF").gradient
                        ))
                }
                .disabled(requestSent)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 24)
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
