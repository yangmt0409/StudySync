import SwiftUI
import SwiftData

struct StudySpaceView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @Query(sort: \FocusSession.startedAt, order: .reverse)
    private var allSessions: [FocusSession]

    @Query private var unlockedItems: [StudySpaceItem]

    @Environment(\.modelContext) private var modelContext

    @State private var newlyUnlocked: DeskItem?
    @State private var showUnlockAnimation = false

    private var totalFocusMinutes: Int {
        allSessions.filter(\.isCompleted).reduce(0) { $0 + $1.actualMinutes }
    }

    private var totalFocusHours: Int { totalFocusMinutes / 60 }

    private var unlockedItemIds: Set<String> {
        Set(unlockedItems.map(\.itemId))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color(hex: "#1a1a2e"), Color(hex: "#16213e")]
                        : [Color(hex: "#f0f4ff"), Color(hex: "#e8eeff")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SSSpacing.xxl) {
                        // My desk visualization
                        deskView

                        // Stats
                        statsCard

                        // Item catalog
                        catalogSection
                    }
                    .padding(.horizontal, SSSpacing.xl)
                    .padding(.top, SSSpacing.md)
                    .padding(.bottom, SSSpacing.xxxl)
                }

                // Unlock animation overlay
                if showUnlockAnimation, let item = newlyUnlocked {
                    unlockOverlay(item)
                }
            }
            .navigationTitle(L10n.studySpaceTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { checkForNewUnlocks() }
            .task {
                // Pull desk decoration unlocks from Firestore.
                // Then re-evaluate unlocks against pulled focus history.
                await StudySpaceItemSyncService.shared.pullAll(context: modelContext)
                checkForNewUnlocks()
            }
        }
    }

    // MARK: - Desk Visualization

    private var deskView: some View {
        VStack(spacing: 0) {
            // Desktop items (3 rows max)
            let items = StudySpaceItem.catalog.filter { unlockedItemIds.contains($0.id) }

            if items.isEmpty {
                VStack(spacing: SSSpacing.md) {
                    Text("🪑")
                        .font(.system(size: 60))
                    Text(L10n.studySpaceEmpty)
                        .font(SSFont.secondary)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            } else {
                // Desk surface with items on it
                ZStack {
                    // Desk surface
                    RoundedRectangle(cornerRadius: SSRadius.large)
                        .fill(
                            LinearGradient(
                                colors: colorScheme == .dark
                                    ? [Color(hex: "#2d2d3f"), Color(hex: "#23233a")]
                                    : [Color(hex: "#8B7355"), Color(hex: "#6B5B45")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 200)
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)

                    // Items arranged on desk
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SSSpacing.xs), count: min(items.count, 7)), spacing: SSSpacing.md) {
                        ForEach(items) { item in
                            VStack(spacing: 2) {
                                Text(item.emoji)
                                    .font(.system(size: items.count > 7 ? 24 : 32))
                                Text(item.name)
                                    .font(.system(size: 8))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
                    .padding(SSSpacing.xl)
                }
            }
        }
    }

    // MARK: - Stats

    private var statsCard: some View {
        HStack(spacing: 0) {
            statColumn(value: "\(totalFocusHours)", label: L10n.studySpaceHours, icon: "clock.fill", color: SSColor.brandPurple)

            RoundedRectangle(cornerRadius: 1).fill(Color(.separator).opacity(0.3)).frame(width: 1, height: 32)

            statColumn(value: "\(unlockedItems.count)", label: L10n.studySpaceUnlocked, icon: "gift.fill", color: Color(hex: "#F59E0B"))

            RoundedRectangle(cornerRadius: 1).fill(Color(.separator).opacity(0.3)).frame(width: 1, height: 32)

            let nextItem = StudySpaceItem.catalog.first { !unlockedItemIds.contains($0.id) }
            statColumn(value: nextItem != nil ? "\(nextItem!.unlockHours)h" : "✅", label: L10n.studySpaceNextAt, icon: "lock.fill", color: .secondary)
        }
        .padding(.vertical, SSSpacing.xl)
        .background(RoundedRectangle(cornerRadius: SSRadius.card).fill(SSColor.backgroundCard))
    }

    private func statColumn(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(SSFont.secondary).foregroundStyle(color)
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded))
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Catalog

    private var catalogSection: some View {
        VStack(alignment: .leading, spacing: SSSpacing.lg) {
            Text(L10n.studySpaceCatalog)
                .font(SSFont.sectionHeader)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            LazyVGrid(columns: iPadGridColumns(iPhone: 4, scale: 1.75, spacing: SSSpacing.md, sizeClass: hSizeClass), spacing: SSSpacing.md) {
                ForEach(StudySpaceItem.catalog) { item in
                    let isUnlocked = unlockedItemIds.contains(item.id)

                    VStack(spacing: SSSpacing.sm) {
                        Text(isUnlocked ? item.emoji : "🔒")
                            .font(SSFont.emojiLarge)
                            .frame(width: 50, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: SSRadius.fieldCard)
                                    .fill(isUnlocked
                                          ? Color(hex: "#F59E0B").opacity(0.1)
                                          : Color(.tertiarySystemFill))
                            )

                        Text(item.name)
                            .font(.system(size: 11, weight: isUnlocked ? .medium : .regular))
                            .foregroundStyle(isUnlocked ? .primary : .tertiary)
                            .lineLimit(1)

                        Text("\(item.unlockHours)h")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(isUnlocked ? Color(hex: "#F59E0B") : Color.gray.opacity(SSOpacity.elevatedShadow))
                    }
                }
            }
        }
        .padding(SSSpacing.xl)
        .background(RoundedRectangle(cornerRadius: SSRadius.card).fill(SSColor.backgroundCard))
    }

    // MARK: - Unlock Logic

    private func checkForNewUnlocks() {
        for item in StudySpaceItem.catalog {
            if totalFocusMinutes >= item.unlockMinutes && !unlockedItemIds.contains(item.id) {
                let unlocked = StudySpaceItem(itemId: item.id)
                modelContext.insert(unlocked)
                StudySpaceItemSyncService.shared.pushItem(unlocked)

                // Show animation for the highest tier newly unlocked item
                newlyUnlocked = item
            }
        }

        if newlyUnlocked != nil {
            withAnimation(.spring(duration: 0.5)) { showUnlockAnimation = true }
        }
    }

    private func unlockOverlay(_ item: DeskItem) -> some View {
        ZStack {
            Color.black.opacity(SSOpacity.disabled).ignoresSafeArea()
                .onTapGesture {
                    withAnimation { showUnlockAnimation = false; newlyUnlocked = nil }
                }

            VStack(spacing: SSSpacing.xxl) {
                Text(item.emoji)
                    .font(.system(size: 64))

                Text(L10n.studySpaceNewItem)
                    .font(.system(size: 22, weight: .bold))

                Text(item.name)
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)

                Text(L10n.studySpaceUnlockedAt(item.unlockHours))
                    .font(SSFont.caption)
                    .foregroundStyle(.tertiary)

                Button {
                    withAnimation(.spring(duration: 0.3)) { showUnlockAnimation = false; newlyUnlocked = nil }
                } label: {
                    Text(L10n.done)
                        .font(SSFont.bodySemibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SSSpacing.lgXl)
                        .background(RoundedRectangle(cornerRadius: SSRadius.medium).fill(LinearGradient(colors: [Color(hex: "#F59E0B"), Color(hex: "#F97316")], startPoint: .leading, endPoint: .trailing)))
                }
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: 24).fill(SSColor.backgroundCard))
            .padding(.horizontal, 40)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }
}
