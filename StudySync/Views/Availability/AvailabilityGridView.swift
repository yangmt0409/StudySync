import SwiftUI

// MARK: - Display Row (for collapsed mode)

enum DisplayRow: Identifiable {
    case normal(index: Int)
    case collapsed(startIndex: Int, endIndex: Int, status: AvailabilityStatus)

    var id: String {
        switch self {
        case .normal(let i): return "n\(i)"
        case .collapsed(let s, let e, _): return "c\(s)-\(e)"
        }
    }
}

// MARK: - Grid View

/// A 7-day × 48-slot availability grid.
/// Does NOT contain its own ScrollView — the caller should wrap it in one.
/// Use `AvailabilityGridView.dayHeader(...)` separately for a pinned header.
struct AvailabilityGridView: View {
    let dateStrings: [String]
    let dayWidth: CGFloat
    @Binding var weekData: [String: String]
    var isEditable: Bool = false
    var collapseLongRuns: Bool = false
    var selectedBrush: AvailabilityStatus = .available

    /// Callback when a cell is painted (dateString, slotIndex, status)
    var onPaint: ((String, Int, AvailabilityStatus) -> Void)?

    // Layout constants
    static let timeLabelWidth: CGFloat = 48
    private let cellHeight: CGFloat = 24
    private let cellSpacing: CGFloat = 1

    // MARK: - Body

    var body: some View {
        if collapseLongRuns {
            let rows = Self.computeDisplayRows(weekData: weekData, dateStrings: dateStrings)
            VStack(spacing: cellSpacing) {
                ForEach(rows) { row in
                    switch row {
                    case .normal(let index):
                        timeRow(row: index)
                    case .collapsed(let start, let end, let status):
                        collapsedRow(startIndex: start, endIndex: end, status: status)
                    }
                }
            }
        } else {
            VStack(spacing: cellSpacing) {
                ForEach(0..<DaySlots.count, id: \.self) { row in
                    timeRow(row: row)
                }
            }
        }
    }

    // MARK: - Normal Time Row

    private func timeRow(row: Int) -> some View {
        HStack(spacing: cellSpacing) {
            Text(DaySlots.timeLabel(for: row))
                .font(DaySlots.isFullHour(row) ? SSFont.badge : .system(size: 9))
                .foregroundStyle(DaySlots.isFullHour(row) ? .primary : .tertiary)
                .frame(width: Self.timeLabelWidth, height: cellHeight, alignment: .trailing)
                .padding(.trailing, 4)

            ForEach(Array(dateStrings.enumerated()), id: \.offset) { _, dateStr in
                let slots = DaySlots.parse(weekData[dateStr] ?? DaySlots.allSleeping)
                let status = row < slots.count ? slots[row] : .sleeping

                Rectangle()
                    .fill(status.color.opacity(0.7))
                    .frame(width: dayWidth, height: cellHeight)
                    .overlay(alignment: .top) {
                        if DaySlots.isFullHour(row) {
                            Rectangle()
                                .fill(Color.primary.opacity(0.06))
                                .frame(height: 0.5)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard isEditable else { return }
                        onPaint?(dateStr, row, selectedBrush)
                        HapticEngine.shared.selection()
                    }
            }
        }
    }

    // MARK: - Collapsed Row

    private func collapsedRow(startIndex: Int, endIndex: Int, status: AvailabilityStatus) -> some View {
        let startTime = DaySlots.timeLabel(for: startIndex)
        let endSlot = endIndex + 1
        let endTime = endSlot < DaySlots.count
            ? DaySlots.timeLabel(for: endSlot)
            : "24:00"
        let slotCount = endIndex - startIndex + 1
        let durationText = Self.formatDuration(slots: slotCount)

        return HStack(spacing: 0) {
            // Time range label
            VStack(alignment: .trailing, spacing: 1) {
                Text(startTime)
                    .font(SSFont.badge)
                Text(verbatim: "-\(endTime)")
                    .font(.system(size: 9))
            }
            .foregroundStyle(.secondary)
            .frame(width: Self.timeLabelWidth, alignment: .trailing)
            .padding(.trailing, 4)

            // Collapsed status bar
            HStack(spacing: 6) {
                Image(systemName: status.icon)
                    .font(.caption2)
                Text(status.label)
                    .font(SSFont.badge)
                Text(verbatim: "·")
                    .font(SSFont.badge)
                    .foregroundStyle(.quaternary)
                Text(durationText)
                    .font(SSFont.badge)
            }
            .foregroundStyle(status.color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                    .fill(status.color.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                    .strokeBorder(status.color.opacity(0.15), lineWidth: 0.5)
            )
        }
        .padding(.vertical, 2)
    }

    // MARK: - Collapsing Logic

    /// Analyze all 7 days and collapse rows where ALL days share the same status
    /// for 4+ consecutive slots (2+ hours).
    static func computeDisplayRows(
        weekData: [String: String],
        dateStrings: [String],
        minRunLength: Int = 4
    ) -> [DisplayRow] {
        // Step 1: For each row, check if ALL days have the same status
        var uniformStatus: [AvailabilityStatus?] = Array(repeating: nil, count: DaySlots.count)

        for row in 0..<DaySlots.count {
            var first: AvailabilityStatus? = nil
            var allSame = true
            for dateStr in dateStrings {
                let slots = DaySlots.parse(weekData[dateStr] ?? DaySlots.allSleeping)
                let s = row < slots.count ? slots[row] : .sleeping
                if first == nil { first = s }
                else if s != first { allSame = false; break }
            }
            uniformStatus[row] = allSame ? first : nil
        }

        // Step 2: Group consecutive rows with same uniform status
        var result: [DisplayRow] = []
        var i = 0

        while i < DaySlots.count {
            if let status = uniformStatus[i] {
                var j = i + 1
                while j < DaySlots.count, uniformStatus[j] == status { j += 1 }
                let runLength = j - i
                if runLength >= minRunLength {
                    result.append(.collapsed(startIndex: i, endIndex: j - 1, status: status))
                } else {
                    for k in i..<j { result.append(.normal(index: k)) }
                }
                i = j
            } else {
                result.append(.normal(index: i))
                i += 1
            }
        }

        return result
    }

    /// Format slot count into readable duration.
    private static func formatDuration(slots: Int) -> String {
        let hours = slots / 2
        let mins = (slots % 2) * 30
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)min"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)min"
        }
    }

    // MARK: - Pinned Day Header (call separately, place outside ScrollView)

    static func dayHeader(dateStrings: [String], dayWidth: CGFloat) -> some View {
        let dayFmt: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "M/d"
            f.locale = Locale.current
            return f
        }()
        let weekdayFmt: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "EEE"
            f.locale = Locale.current
            return f
        }()
        let parser: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.locale = Locale(identifier: "en_US_POSIX")
            return f
        }()

        return HStack(spacing: 1) {
            Color.clear
                .frame(width: timeLabelWidth, height: 40)

            ForEach(dateStrings, id: \.self) { dateStr in
                let date = parser.date(from: dateStr) ?? Date()
                let isToday = Calendar.current.isDateInToday(date)

                VStack(spacing: 2) {
                    Text(dayFmt.string(from: date))
                        .font(SSFont.badge)
                        .foregroundStyle(isToday ? SSColor.brand : .secondary)
                    Text(weekdayFmt.string(from: date))
                        .font(SSFont.badge)
                        .fontWeight(isToday ? .bold : .regular)
                        .foregroundStyle(isToday ? SSColor.brand : .secondary)
                }
                .frame(width: dayWidth, height: 40)
                .background(
                    isToday
                    ? RoundedRectangle(cornerRadius: 6).fill(SSColor.brand.opacity(0.1))
                    : nil
                )
            }
        }
    }
}
