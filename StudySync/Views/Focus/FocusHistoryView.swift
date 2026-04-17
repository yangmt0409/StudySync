import SwiftUI
import SwiftData

struct FocusHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<FocusSession> { $0.isCompleted == true },
           sort: \FocusSession.startedAt, order: .reverse)
    private var sessions: [FocusSession]

    private var grouped: [(String, [FocusSession])] {
        Dictionary(grouping: sessions) { $0.dayLabel }
            .sorted { a, b in
                guard let ad = a.value.first?.startedAt, let bd = b.value.first?.startedAt else { return false }
                return ad > bd
            }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SSColor.backgroundPrimary
                    .ignoresSafeArea()

                if sessions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 36))
                            .foregroundStyle(.tertiary)
                        Text(L10n.focusNoHistory)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(grouped, id: \.0) { day, daySessions in
                                VStack(alignment: .leading, spacing: 8) {
                                    // Day header
                                    HStack {
                                        Text(day)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.secondary)

                                        Spacer()

                                        let dayTotal = daySessions.reduce(0) { $0 + $1.actualMinutes }
                                        Text(L10n.focusMinutes(dayTotal))
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.tertiary)
                                    }

                                    ForEach(daySessions) { session in
                                        sessionRow(session)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, SSSpacing.xl)
                        .padding(.top, SSSpacing.md)
                        .padding(.bottom, SSSpacing.xxl)
                    }
                }
            }
            .navigationTitle(L10n.focusHistory)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.done) { dismiss() }
                }
            }
        }
    }

    private func sessionRow(_ session: FocusSession) -> some View {
        HStack(spacing: 12) {
            Text(session.emoji)
                .font(.system(size: 22))
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(Color(.tertiarySystemFill))
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(session.formattedDuration)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))

                    Text("/ \(session.durationMinutes)min")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }

                Text(session.timeLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.green)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
    }
}

#Preview {
    FocusHistoryView()
        .modelContainer(for: FocusSession.self, inMemory: true)
}
