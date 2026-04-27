import SwiftUI

struct BadgeGridView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var auth: AuthService { .shared }

    private var earnedIds: [String] {
        auth.userProfile?.badges ?? []
    }

    var body: some View {
        ScrollView {
            VStack(spacing: SSSpacing.xxl) {
                // Summary
                summaryCard

                // By category
                ForEach(BadgeCategory.allCases, id: \.rawValue) { category in
                    badgeSection(category)
                }
            }
            .padding(.horizontal, SSSpacing.xl)
            .padding(.top, SSSpacing.md)
            .padding(.bottom, SSSpacing.xxl)
        }
        .background {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
        }
        .navigationTitle(L10n.socialBadges)
    }

    // MARK: - Summary

    private var summaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: SSSpacing.xs) {
                Text("\(earnedIds.count) / \(Badge.all.count)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(SSColor.brand)
                Text(L10n.socialBadgesEarned)
                    .font(SSFont.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Show recent badges
            HStack(spacing: -8) {
                ForEach(Badge.earned(from: earnedIds).suffix(4)) { badge in
                    Text(badge.emoji)
                        .font(.system(size: 24))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle().fill(badge.color.opacity(SSOpacity.lightTint))
                        )
                }
            }
        }
        .padding(SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Section

    private func badgeSection(_ category: BadgeCategory) -> some View {
        let badges = Badge.all.filter { $0.category == category }

        return VStack(alignment: .leading, spacing: SSSpacing.mdLg) {
            Text(category.displayName)
                .font(SSFont.bodySemibold)

            LazyVGrid(columns: iPadGridColumns(iPhone: 3, scale: 1.7, spacing: SSSpacing.lg, sizeClass: hSizeClass), spacing: SSSpacing.lg) {
                ForEach(badges) { badge in
                    badgeCell(badge, earned: earnedIds.contains(badge.id))
                }
            }
        }
    }

    private func badgeCell(_ badge: Badge, earned: Bool) -> some View {
        VStack(spacing: SSSpacing.sm) {
            Text(badge.emoji)
                .font(.system(size: 32))
                .grayscale(earned ? 0 : 1)
                .opacity(earned ? 1 : 0.3)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(earned
                              ? badge.color.opacity(SSOpacity.lightTint)
                              : Color(.tertiarySystemFill))
                )
                .overlay(
                    Circle()
                        .stroke(earned ? badge.color : .clear, lineWidth: 2)
                )

            Text(badge.name)
                .font(SSFont.badge)
                .foregroundStyle(earned ? .primary : .secondary)
                .lineLimit(1)

            Text(badge.description)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SSSpacing.md)
    }
}

#Preview {
    NavigationStack {
        BadgeGridView()
    }
}
