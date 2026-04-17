import SwiftUI

struct BadgeGridView: View {
    @Environment(\.colorScheme) private var colorScheme
    private var auth: AuthService { .shared }

    private var earnedIds: [String] {
        auth.userProfile?.badges ?? []
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary
                summaryCard

                // By category
                ForEach(BadgeCategory.allCases, id: \.rawValue) { category in
                    badgeSection(category)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
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
            VStack(alignment: .leading, spacing: 4) {
                Text("\(earnedIds.count) / \(Badge.all.count)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "#5B7FFF"))
                Text(L10n.socialBadgesEarned)
                    .font(.system(size: 13))
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
                            Circle().fill(badge.color.opacity(0.15))
                        )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Section

    private func badgeSection(_ category: BadgeCategory) -> some View {
        let badges = Badge.all.filter { $0.category == category }

        return VStack(alignment: .leading, spacing: 10) {
            Text(category.displayName)
                .font(.system(size: 16, weight: .semibold))

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(badges) { badge in
                    badgeCell(badge, earned: earnedIds.contains(badge.id))
                }
            }
        }
    }

    private func badgeCell(_ badge: Badge, earned: Bool) -> some View {
        VStack(spacing: 6) {
            Text(badge.emoji)
                .font(.system(size: 32))
                .grayscale(earned ? 0 : 1)
                .opacity(earned ? 1 : 0.3)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(earned
                              ? badge.color.opacity(0.15)
                              : Color(.tertiarySystemFill))
                )
                .overlay(
                    Circle()
                        .stroke(earned ? badge.color : .clear, lineWidth: 2)
                )

            Text(badge.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(earned ? .primary : .secondary)
                .lineLimit(1)

            Text(badge.description)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        BadgeGridView()
    }
}
