import SwiftUI

struct ProjectTimelineView: View {
    @Bindable var viewModel: TeamProjectViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var color: Color {
        Color(hex: viewModel.currentProject?.colorHex ?? "#5B7FFF")
    }

    var body: some View {
        ZStack {
            SSColor.backgroundPrimary
                .ignoresSafeArea()

            if viewModel.activities.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.activities.enumerated()), id: \.element.id) { index, activity in
                            timelineRow(activity, isLast: index == viewModel.activities.count - 1)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .navigationTitle(L10n.projectTimeline)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(L10n.projectNoActivity)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            Text(L10n.projectNoActivityDesc)
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Timeline Row

    private func timelineRow(_ activity: ProjectActivity, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Left: line + dot
            VStack(spacing: 0) {
                Circle()
                    .fill(Color(hex: activity.type.colorHex))
                    .frame(width: 12, height: 12)
                    .padding(.top, 6)

                if !isLast {
                    Rectangle()
                        .fill(Color(.separator).opacity(0.4))
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)

            // Right: content
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: activity.type.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: activity.type.colorHex))

                    Text(activity.actorEmoji)
                        .font(.system(size: 18))

                    Text(activity.type.description(actorName: activity.actorName, detail: activity.detail))
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }

                Text(activity.timestamp.relativeTimelineLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 42)
            }
            .padding(.bottom, 20)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Date Extension for Timeline

private extension Date {
    private static let timelineDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d HH:mm"
        return f
    }()

    var relativeTimelineLabel: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        if interval < 60 {
            return String(localized: "刚刚")
        } else if interval < 3600 {
            let mins = Int(interval / 60)
            return String(localized: "\(mins) 分钟前")
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return String(localized: "\(hours) 小时前")
        } else if interval < 86400 * 7 {
            let days = Int(interval / 86400)
            return String(localized: "\(days) 天前")
        } else {
            return Self.timelineDateFormatter.string(from: self)
        }
    }
}

#Preview {
    NavigationStack {
        ProjectTimelineView(viewModel: TeamProjectViewModel())
    }
}
