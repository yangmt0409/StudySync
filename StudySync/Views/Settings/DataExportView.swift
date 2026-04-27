import SwiftUI
import SwiftData

struct DataExportView: View {
    @Query(sort: \FocusSession.startedAt, order: .reverse) private var sessions: [FocusSession]
    @Query(sort: \CheckInRecord.date, order: .reverse) private var checkIns: [CheckInRecord]
    @Query(sort: \GradeCourse.name) private var courses: [GradeCourse]

    var body: some View {
        ScrollView {
            VStack(spacing: SSSpacing.xl) {
                // Header
                VStack(spacing: SSSpacing.sm) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(SSColor.brand)
                    Text(L10n.dataExportDesc)
                        .font(SSFont.secondary)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, SSSpacing.xl)
                .padding(.horizontal, SSSpacing.xl)

                // Export Cards
                VStack(spacing: SSSpacing.lg) {
                    exportCard(
                        icon: "timer",
                        iconColor: .orange,
                        title: L10n.exportFocusSessions,
                        count: sessions.count,
                        generateURL: generateFocusCSV
                    )

                    exportCard(
                        icon: "checkmark.seal.fill",
                        iconColor: .green,
                        title: L10n.exportCheckIns,
                        count: checkIns.count,
                        generateURL: generateCheckInCSV
                    )

                    exportCard(
                        icon: "chart.bar.fill",
                        iconColor: SSColor.brand,
                        title: L10n.exportGrades,
                        count: courses.reduce(0) { $0 + $1.components.count },
                        generateURL: generateGradesCSV
                    )
                }
                .padding(.horizontal, SSSpacing.xl)
            }
            .padding(.bottom, SSSpacing.xxxl)
        }
        .background(SSColor.backgroundPrimary)
        .navigationTitle(L10n.dataExport)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Export Card

    @ViewBuilder
    private func exportCard(
        icon: String,
        iconColor: Color,
        title: String,
        count: Int,
        generateURL: () -> URL?
    ) -> some View {
        HStack(spacing: SSSpacing.lg) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                    .fill(iconColor.opacity(SSOpacity.tagBackground))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            // Title + count
            VStack(alignment: .leading, spacing: SSSpacing.xxs) {
                Text(title)
                    .font(SSFont.bodyMedium)
                    .foregroundStyle(.primary)
                Text(count > 0
                     ? "\(count) 条记录"
                     : L10n.exportNoData)
                    .font(SSFont.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Export button
            if count > 0, let url = generateURL() {
                ShareLink(item: url) {
                    HStack(spacing: SSSpacing.xs) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .semibold))
                        Text(L10n.exportCSV)
                            .font(SSFont.chipLabel)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, SSSpacing.lg)
                    .padding(.vertical, SSSpacing.md)
                    .background(
                        Capsule()
                            .fill(SSColor.brand)
                    )
                }
            } else {
                Text(L10n.exportNoData)
                    .font(SSFont.chipLabel)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .stroke(SSColor.brand.opacity(SSOpacity.border), lineWidth: SSBorder.cardWidth)
        )
        .ssCardShadow(color: SSColor.brand)
    }

    // MARK: - CSV Generators

    private func generateFocusCSV() -> URL? {
        var csv = "Date,Emoji,Label,Duration (min),Actual (sec),Foreground (sec),Completed\n"
        let df = ISO8601DateFormatter()
        for s in sessions {
            let date = df.string(from: s.startedAt)
            let label = s.label.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\"\(date)\",\"\(s.emoji)\",\"\(label)\",\(s.durationMinutes),\(s.actualSeconds),\(s.foregroundSeconds),\(s.isCompleted)\n"
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("StudySync_Focus_Sessions.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func generateCheckInCSV() -> URL? {
        var csv = "Date,Note,Goal\n"
        let df = ISO8601DateFormatter()
        for c in checkIns {
            let date = df.string(from: c.date)
            let note = c.note.replacingOccurrences(of: "\"", with: "\"\"")
            let goalTitle = (c.goal?.title ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\"\(date)\",\"\(note)\",\"\(goalTitle)\"\n"
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("StudySync_CheckIn_Records.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func generateGradesCSV() -> URL? {
        var csv = "Course,Course Emoji,Component,Weight (%),Score (%),Is Final\n"
        for course in courses {
            let courseName = course.name.replacingOccurrences(of: "\"", with: "\"\"")
            for component in course.sortedComponents {
                let compName = component.name.replacingOccurrences(of: "\"", with: "\"\"")
                let scoreStr = component.effectivePercent.map { String(format: "%.2f", $0) } ?? ""
                csv += "\"\(courseName)\",\"\(course.emoji)\",\"\(compName)\",\(component.weightPercent),\"\(scoreStr)\",\(component.isFinal)\n"
            }
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("StudySync_Grades.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

#Preview {
    NavigationStack {
        DataExportView()
    }
    .modelContainer(for: [FocusSession.self, CheckInRecord.self, GradeCourse.self], inMemory: true)
}
