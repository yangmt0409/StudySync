import SwiftUI

struct FriendAvailabilityView: View {
    let friendUid: String
    let friendName: String
    let friendEmoji: String

    private var service: AvailabilityService { .shared }

    @State private var weekData: [String: String] = [:]
    @State private var isLoading = true
    @State private var hasData = false

    var body: some View {
        GeometryReader { geo in
            let dayWidth = (geo.size.width - AvailabilityGridView.timeLabelWidth - SSSpacing.xl * 2) / CGFloat(service.weekDateStrings.count)

            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 0) {
                    // Legend (pinned)
                    legendBar
                        .padding(.horizontal, SSSpacing.xl)
                        .padding(.vertical, SSSpacing.md)

                    // Notice if friend hasn't configured timeline (pinned)
                    if !hasData {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text(L10n.avNotConfigured)
                                .font(SSFont.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, SSSpacing.xl)
                        .padding(.bottom, SSSpacing.xs)
                    }

                    // Day header (pinned)
                    AvailabilityGridView.dayHeader(
                        dateStrings: service.weekDateStrings,
                        dayWidth: dayWidth
                    )
                    .padding(.horizontal, SSSpacing.xl)
                    .padding(.bottom, 4)
                    .background(SSColor.backgroundPrimary)

                    // Scrollable: grid rows (collapsed for browse)
                    ScrollView(.vertical, showsIndicators: true) {
                        AvailabilityGridView(
                            dateStrings: service.weekDateStrings,
                            dayWidth: dayWidth,
                            weekData: .constant(weekData),
                            isEditable: false,
                            collapseLongRuns: true
                        )
                        .padding(.horizontal, SSSpacing.xl)
                        .padding(.bottom, SSSpacing.xxxl)
                    }
                }
            }
        }
        .background {
            SSColor.backgroundPrimary.ignoresSafeArea()
        }
        .navigationTitle(L10n.avFriendTitle(friendName))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }

    // MARK: - Legend

    private var legendBar: some View {
        HStack(spacing: SSSpacing.lg) {
            ForEach(AvailabilityStatus.allCases) { status in
                HStack(spacing: 4) {
                    Circle()
                        .fill(status.color)
                        .frame(width: 10, height: 10)
                    Text(status.label)
                        .font(SSFont.badge)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    // MARK: - Load

    private func loadData() async {
        isLoading = true
        let data = await service.loadFriendWeek(uid: friendUid)

        // Fill: use remote data if exists, else all-sleeping (gray)
        var filled: [String: String] = [:]
        var foundAny = false
        for d in service.weekDateStrings {
            if let slots = data[d] {
                filled[d] = slots
                foundAny = true
            } else {
                filled[d] = DaySlots.allSleeping
            }
        }
        weekData = filled
        hasData = foundAny
        isLoading = false
    }
}
