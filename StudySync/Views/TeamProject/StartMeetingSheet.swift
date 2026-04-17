import SwiftUI

struct StartMeetingSheet: View {
    @Bindable var viewModel: TeamProjectViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var meetingLink = ""
    @FocusState private var isLinkFocused: Bool

    private var detectedPlatform: MeetingPlatform {
        MeetingPlatform.detect(from: meetingLink)
    }

    private var isValidLink: Bool {
        guard let url = URL(string: meetingLink),
              let scheme = url.scheme else { return false }
        return ["http", "https"].contains(scheme.lowercased()) && url.host != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SSSpacing.xxl) {
                    // Hero icon
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(SSColor.brand)
                        .padding(.top, SSSpacing.xxxl)

                    Text(L10n.meetingStartDesc)
                        .font(SSFont.secondary)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    // Link input
                    VStack(spacing: SSSpacing.md) {
                        HStack {
                            TextField(L10n.meetingLinkPlaceholder, text: $meetingLink)
                                .font(SSFont.body)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($isLinkFocused)

                            Button {
                                if let clip = UIPasteboard.general.string {
                                    meetingLink = clip
                                }
                                HapticEngine.shared.lightImpact()
                            } label: {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 16))
                                    .foregroundStyle(SSColor.brand)
                            }
                        }
                        .padding(SSSpacing.xl)
                        .background(
                            RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                                .fill(SSColor.backgroundCard)
                        )

                        // Platform detection badge
                        if !meetingLink.isEmpty {
                            HStack(spacing: SSSpacing.md) {
                                Image(systemName: detectedPlatform.icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(hex: detectedPlatform.colorHex))
                                Text(detectedPlatform.displayName)
                                    .font(SSFont.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, SSSpacing.xs)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.spring(duration: 0.3), value: meetingLink.isEmpty)

                    // Platform examples
                    VStack(spacing: SSSpacing.md) {
                        ForEach(MeetingPlatform.allCases.filter { $0 != .other }, id: \.self) { platform in
                            HStack(spacing: SSSpacing.lg) {
                                Image(systemName: platform.icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color(hex: platform.colorHex))
                                    .frame(width: 24)
                                Text(platform.displayName)
                                    .font(SSFont.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                    }
                    .padding(SSSpacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                            .fill(SSColor.backgroundCard)
                    )

                    // Start button
                    Button {
                        Task {
                            await viewModel.startMeeting(link: meetingLink, platform: detectedPlatform)
                            dismiss()
                        }
                        HapticEngine.shared.success()
                    } label: {
                        Text(L10n.meetingStart)
                            .font(SSFont.bodySemibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, SSSpacing.lg)
                            .background(
                                RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                                    .fill(isValidLink ? SSColor.brand : SSColor.brand.opacity(0.4))
                            )
                    }
                    .disabled(!isValidLink)
                }
                .padding(.horizontal, SSSpacing.xl)
            }
            .background {
                SSColor.backgroundPrimary.ignoresSafeArea()
            }
            .navigationTitle(L10n.meetingStart)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
            .onAppear { isLinkFocused = true }
        }
    }
}
