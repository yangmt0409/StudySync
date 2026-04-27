import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SSSpacing.lg) {
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
                                iconColor: SSColor.brand,
                                title: L10n.about
                            )
                        }
                    }
                    .padding(.horizontal, SSSpacing.xl)
                    .padding(.top, SSSpacing.md)
                    .padding(.bottom, SSSpacing.xxl)
                }
            }
            .navigationTitle(L10n.more)
        }
    }

    private func moreRow(icon: String, iconColor: Color, title: String) -> some View {
        HStack(spacing: SSSpacing.lgXl) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 32)

            Text(title)
                .font(SSFont.bodyMedium)
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(SSFont.sectionHeader)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, SSSpacing.xl)
        .padding(.vertical, SSSpacing.lgXl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    MoreView()
}
