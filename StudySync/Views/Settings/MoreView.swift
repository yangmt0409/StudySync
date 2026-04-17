import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            moreRow(
                                icon: "gearshape.fill",
                                iconColor: Color(.systemGray),
                                title: L10n.tabSettings
                            )
                        }

                        NavigationLink {
                            AboutView()
                        } label: {
                            moreRow(
                                icon: "info.circle.fill",
                                iconColor: Color(hex: "#5B7FFF"),
                                title: L10n.about
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(L10n.more)
        }
    }

    private func moreRow(icon: String, iconColor: Color, title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 32)

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    MoreView()
}
