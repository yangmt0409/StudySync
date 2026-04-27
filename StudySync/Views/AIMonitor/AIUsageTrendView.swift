import SwiftUI
import SwiftData
import Charts

/// Displays a usage trend chart for a given AI account over the past 24h / 7d.
struct AIUsageTrendView: View {
    let account: AIAccount

    @Query private var allSnapshots: [AIUsageSnapshot]
    @State private var timeRange: TrendRange = .day

    enum TrendRange: String, CaseIterable {
        case day = "24h"
        case week = "7d"
    }

    init(account: AIAccount) {
        self.account = account
        // Query all snapshots for this account
        let accountId = account.id
        _allSnapshots = Query(
            filter: #Predicate<AIUsageSnapshot> { $0.accountId == accountId },
            sort: \AIUsageSnapshot.timestamp
        )
    }

    private var filteredSnapshots: [AIUsageSnapshot] {
        let cutoff: Date
        switch timeRange {
        case .day:
            cutoff = Date().addingTimeInterval(-24 * 3600)
        case .week:
            cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        }
        return allSnapshots.filter { $0.timestamp > cutoff }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.aiUsageTrend)
                    .font(.headline)
                Spacer()
                Picker("", selection: $timeRange) {
                    ForEach(TrendRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }

            if filteredSnapshots.count < 2 {
                // Not enough data
                VStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text(L10n.aiTrendNoData)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
            } else {
                chartView
                    .frame(height: 150)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Chart

    private var chartView: some View {
        Chart {
            ForEach(filteredSnapshots, id: \.id) { snapshot in
                LineMark(
                    x: .value("Time", snapshot.timestamp),
                    y: .value("Usage", snapshot.utilization1),
                    series: .value("Window", windowLabel1)
                )
                .foregroundStyle(Color(hex: account.provider.colorHex))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("Time", snapshot.timestamp),
                    y: .value("Usage", snapshot.utilization1),
                    series: .value("Window", windowLabel1)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [Color(hex: account.provider.colorHex).opacity(0.2), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            // Secondary window (if applicable)
            if account.provider == .claude {
                ForEach(filteredSnapshots, id: \.id) { snapshot in
                    LineMark(
                        x: .value("Time", snapshot.timestamp),
                        y: .value("Usage", snapshot.utilization2),
                        series: .value("Window", windowLabel2)
                    )
                    .foregroundStyle(.secondary)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }

            // Threshold line
            RuleMark(y: .value("Threshold", Double(account.notifyThreshold)))
                .foregroundStyle(.red.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.tertiary)
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)%")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.quaternary)
                AxisValueLabel(format: timeRange == .day ? .dateTime.hour() : .dateTime.weekday(.abbreviated))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .chartLegend(position: .bottom, spacing: 8) {
            HStack(spacing: 16) {
                Label(windowLabel1, systemImage: "line.diagonal")
                    .font(.caption2)
                    .foregroundStyle(Color(hex: account.provider.colorHex))
                if account.provider == .claude {
                    Label(windowLabel2, systemImage: "line.diagonal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var windowLabel1: String { account.provider.windowLabel1 }
    private var windowLabel2: String { account.provider.windowLabel2 }
}
