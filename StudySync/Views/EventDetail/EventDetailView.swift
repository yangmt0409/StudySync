import SwiftUI
import SwiftData
import PhotosUI

struct EventDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var event: CountdownEvent

    @State private var selectedTab = 0
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showDeleteConfirm = false
    @State private var showShareCard = false
    @State private var showCelebration = false
    @State private var didDelete = false
    @State private var showingPaywall = false

    private var isPro: Bool { StoreManager.shared.isPro }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab 内容（预览卡片在每个 tab 的 ScrollView 内）
                TabView(selection: $selectedTab) {
                    tabContent { basicInfoTab }.tag(0)
                    tabContent { displayTab }.tag(1)
                    tabContent { themeTab }.tag(2)
                    tabContent { moreTab }.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // 底部 Tab 栏
                bottomTabBar
            }
            .background {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
            }
            .navigationTitle(L10n.eventDetail)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.done) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onDisappear {
                // Sync any inline edits (theme, color, font, etc.) to Firestore.
                // Skip if we just deleted the event from this sheet.
                guard !didDelete else { return }
                CountdownEventSyncService.shared.pushEvent(event)
            }
            .sheet(isPresented: $showShareCard) {
                ShareCardPreviewView(event: event)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .fullScreenCover(isPresented: $showCelebration) {
                CelebrationView(
                    eventTitle: event.title,
                    colorHex: event.colorHex,
                    onDismiss: { showCelebration = false }
                )
                .background(ClearBackground())
            }
            .alert(L10n.confirmDelete, isPresented: $showDeleteConfirm) {
                Button(L10n.delete, role: .destructive) {
                    let eventId = event.id
                    didDelete = true
                    modelContext.delete(event)
                    CountdownEventSyncService.shared.deleteEvent(id: eventId)
                    dismiss()
                }
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                Text(L10n.deleteWarning)
            }
        }
    }

    // MARK: - Tab Content Wrapper

    @ViewBuilder
    private func tabContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                previewCard
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                Divider()
                    .padding(.bottom, 8)

                content()
            }
        }
    }

    // MARK: - Font Helper

    private func eventFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let opt = FontOption(rawValue: event.fontName) ?? .default
        return opt.font(size: size, weight: weight)
    }

    // MARK: - Pro Gate

    @ViewBuilder
    private func proGated<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let locked = !isPro
        content()
            .allowsHitTesting(!locked)
            .opacity(locked ? 0.55 : 1)
            .overlay(alignment: .topTrailing) {
                if locked {
                    Label("PRO", systemImage: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.orange.gradient))
                        .padding(8)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                if locked {
                    Button {
                        HapticEngine.shared.lightImpact()
                        showingPaywall = true
                    } label: {
                        Color.clear.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        VStack(spacing: 12) {
            switch event.themeStyle {
            case .grid:
                gridPreview
            case .ring:
                ringPreview
            case .bar:
                barPreview
            case .minimal:
                minimalPreview
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: event.colorHex).opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: event.colorHex).opacity(0.15), lineWidth: 1)
        )
    }

    private var gridPreview: some View {
        VStack(spacing: 10) {
            HStack {
                Text(event.title)
                    .font(eventFont(size: 16, weight: .semibold))
                Spacer()
                Text(event.displayText)
                    .font(eventFont(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: event.colorHex))
            }

            DotGridProgressView(
                startDate: event.startDate,
                endDate: event.endDate,
                accentColor: Color(hex: event.colorHex),
                dotShape: event.dotShape,
                timeUnit: event.timeUnit,
                isCompact: true,
                showAsCountUp: event.showAsCountUp
            )
        }
    }

    private var ringPreview: some View {
        HStack(spacing: 16) {
            ProgressRingView(
                progress: event.progress,
                colorHex: event.colorHex,
                lineWidth: 8,
                size: 64
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(eventFont(size: 16, weight: .semibold))
                Text(event.displayText)
                    .font(eventFont(size: 24, weight: .bold))
                    .foregroundStyle(Color(hex: event.colorHex))
            }
            Spacer()
        }
    }

    private var barPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(event.title)
                    .font(eventFont(size: 16, weight: .semibold))
                Spacer()
                Text(event.displayText)
                    .font(eventFont(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: event.colorHex))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: event.colorHex).opacity(0.15))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: event.colorHex))
                        .frame(width: geo.size.width * event.progress)
                }
            }
            .frame(height: 12)

            HStack {
                Text(event.startDate.formattedChinese)
                Spacer()
                Text(event.endDate.formattedChinese)
            }
            .font(eventFont(size: 11))
            .foregroundStyle(.secondary)
        }
    }

    private var minimalPreview: some View {
        VStack(spacing: 4) {
            Text(event.showPercentage ? "\(Int(event.progress * 100))%" : "\(event.primaryCount)")
                .font(eventFont(size: 48, weight: .bold))
                .foregroundStyle(Color(hex: event.colorHex))
            Text(event.showPercentage
                 ? event.title
                 : (event.showAsCountUp
                    ? L10n.unitPassed(event.unitLabel)
                    : L10n.unitLeft(event.unitLabel)))
                .font(eventFont(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Bottom Tab Bar

    private var bottomTabBar: some View {
        HStack(spacing: 0) {
            tabButton(icon: "calendar", title: L10n.tabBasic, index: 0)
            tabButton(icon: "slider.horizontal.3", title: L10n.tabDisplay, index: 1)
            tabButton(icon: "paintbrush.fill", title: L10n.tabTheme, index: 2)
            tabButton(icon: "ellipsis", title: L10n.tabMore, index: 3)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func tabButton(icon: String, title: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(duration: 0.3)) { selectedTab = index }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selectedTab == index ? .blue : .secondary)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Tab 1: Basic Info

    private var basicInfoTab: some View {
        VStack(spacing: 16) {
            GroupBox(L10n.eventInfo) {
                VStack(spacing: 12) {
                    HStack {
                        Text(L10n.titleLabel)
                        Spacer()
                        TextField(L10n.eventName, text: $event.title)
                            .multilineTextAlignment(.trailing)
                    }
                    Divider()
                    HStack {
                        Text("Emoji")
                        Spacer()
                        TextField("", text: $event.emoji)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                    }
                    Divider()
                    Picker(L10n.category, selection: Binding(
                        get: { event.category },
                        set: { event.category = $0 }
                    )) {
                        ForEach(EventCategory.allCases) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            GroupBox(L10n.date) {
                VStack(spacing: 12) {
                    DatePicker(L10n.startDate, selection: $event.startDate, displayedComponents: .date)
                        .environment(\.locale, Locale.current)
                    Divider()
                    DatePicker(L10n.endDate, selection: $event.endDate, displayedComponents: .date)
                        .environment(\.locale, Locale.current)
                }
                .padding(.vertical, 4)
            }

            GroupBox(L10n.noteSection) {
                TextField(L10n.notePlaceholder, text: $event.note, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(.vertical, 4)
            }
        }
        .padding(16)
    }

    // MARK: - Tab 2: Display

    private var displayTab: some View {
        VStack(spacing: 16) {
            GroupBox(L10n.displayMode) {
                VStack(spacing: 12) {
                    Toggle(L10n.showPercentage, isOn: $event.showPercentage)
                    Divider()
                    Toggle(L10n.countUpMode, isOn: $event.showAsCountUp)
                }
                .padding(.vertical, 4)
            }

            GroupBox(L10n.timeUnitSection) {
                Picker(L10n.dotRepresents, selection: Binding(
                    get: { event.timeUnit },
                    set: { event.timeUnit = $0 }
                )) {
                    ForEach(TimeUnit.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 4)
            }

            if event.showAsCountUp {
                GroupBox {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                        Text(L10n.countUpDescription)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
    }

    // MARK: - Tab 3: Theme

    private var themeTab: some View {
        VStack(spacing: 16) {
                // 主题样式选择
                GroupBox(L10n.themeStyle) {
                    HStack(spacing: 12) {
                        ForEach(ThemeStyle.allCases) { style in
                            Button {
                                withAnimation { event.themeStyle = style }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: style.icon)
                                        .font(.system(size: 20))
                                        .frame(width: 44, height: 44)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(event.themeStyle == style
                                                      ? Color(hex: event.colorHex).opacity(0.15)
                                                      : Color(.tertiarySystemFill))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(event.themeStyle == style
                                                        ? Color(hex: event.colorHex) : .clear, lineWidth: 2)
                                        )

                                    Text(style.displayName)
                                        .font(.system(size: 11))
                                }
                                .foregroundStyle(event.themeStyle == style ? Color(hex: event.colorHex) : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }

                // 点形状（仅 grid 模式）
                if event.themeStyle == .grid {
                    GroupBox(L10n.dotShapeSection) {
                        HStack(spacing: 16) {
                            ForEach(DotShape.allCases) { shape in
                                Button {
                                    withAnimation { event.dotShape = shape }
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: shape.icon)
                                            .font(.system(size: 18))
                                            .frame(width: 40, height: 40)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .fill(event.dotShape == shape
                                                          ? Color(hex: event.colorHex).opacity(0.15)
                                                          : Color(.tertiarySystemFill))
                                            )

                                        Text(shape.displayName)
                                            .font(.system(size: 10))
                                    }
                                    .foregroundStyle(event.dotShape == shape ? Color(hex: event.colorHex) : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                }

                // 颜色选择
                GroupBox(L10n.colorSection) {
                    let colors = ["#5B7FFF", "#FF6B6B", "#4ECDC4", "#FFB347",
                                  "#A78BFA", "#F472B6", "#34D399", "#FBBF24",
                                  "#6366F1", "#EC4899"]
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                        ForEach(colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                        .opacity(event.colorHex == hex ? 1 : 0)
                                )
                                .onTapGesture { event.colorHex = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // 背景图片 (Pro)
                proGated {
                    GroupBox(L10n.backgroundImage) {
                        HStack {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label(L10n.selectImage, systemImage: "photo")
                            }

                            Spacer()

                            if event.backgroundImageData != nil {
                                Button(L10n.removeImage, role: .destructive) {
                                    event.backgroundImageData = nil
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .onChange(of: selectedPhoto) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    event.backgroundImageData = data
                                }
                            }
                        }
                    }
                }

                // 字体选择 (Pro)
                proGated {
                GroupBox(L10n.fontSection) {
                    let fontOption = FontOption(rawValue: event.fontName) ?? .default
                    HStack(spacing: 12) {
                        ForEach(FontOption.allCases) { opt in
                            Button {
                                event.fontName = opt.rawValue
                            } label: {
                                VStack(spacing: 4) {
                                    Text("Aa")
                                        .font(opt.font(size: 18, weight: .bold))
                                        .frame(width: 44, height: 44)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(fontOption == opt
                                                      ? Color(hex: event.colorHex).opacity(0.15)
                                                      : Color(.tertiarySystemFill))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(fontOption == opt ? Color(hex: event.colorHex) : .clear, lineWidth: 2)
                                        )

                                    Text(opt.displayName)
                                        .font(.system(size: 10))
                                }
                                .foregroundStyle(fontOption == opt ? Color(hex: event.colorHex) : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                }

                // 文字颜色 (Pro)
                proGated {
                    colorPickerRow(
                        title: L10n.textColor,
                        selectedHex: $event.textColorHex
                    )
                }

                // 圆球颜色 (Pro)
                proGated {
                    colorPickerRow(
                        title: L10n.dotColor,
                        selectedHex: $event.dotColorHex
                    )
                }
        }
        .padding(16)
    }

    // MARK: - Tab 4: More

    private var moreTab: some View {
        VStack(spacing: 16) {
                // 分享 & 庆祝
                GroupBox {
                    VStack(spacing: 12) {
                        Button {
                            showShareCard = true
                            HapticEngine.shared.selection()
                        } label: {
                            Label(L10n.generateShareCard, systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if event.isExpired {
                            Divider()
                            Button {
                                showCelebration = true
                            } label: {
                                Label(L10n.playCelebration, systemImage: "party.popper")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                GroupBox {
                    VStack(spacing: 12) {
                        Toggle(L10n.pinDisplay, isOn: $event.isPinned)
                        Divider()
                        Toggle(L10n.expiryReminder, isOn: $event.notifyEnabled)
                    }
                    .padding(.vertical, 4)
                }

                GroupBox(L10n.infoSection) {
                    VStack(spacing: 8) {
                        // Always show days for the raw totals (stable reference),
                        // then a unit-aware "remaining" row reflecting the picked unit.
                        infoRow(L10n.totalDaysLabel, value: "\(event.totalDays) \(L10n.daysUnit)")
                        Divider()
                        infoRow(L10n.elapsedDaysLabel, value: "\(event.elapsedInUnit) \(event.unitLabel)")
                        Divider()
                        infoRow(L10n.remainingDaysLabel, value: "\(event.remainingInUnit) \(event.unitLabel)")
                        Divider()
                        infoRow(L10n.progressLabel, value: "\(Int(event.progress * 100))%")
                        Divider()
                        infoRow(L10n.createdAtLabel, value: event.createdAt.formattedChinese)
                    }
                    .padding(.vertical, 4)
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        Label(L10n.deleteEvent, systemImage: "trash")
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.red.opacity(0.1))
                    )
                }
            }
        .padding(16)
    }

    private func colorPickerRow(title: String, selectedHex: Binding<String>) -> some View {
        let colorChoices = [
            "#FFFFFF", "#000000", "#5B7FFF", "#FF6B6B",
            "#4ECDC4", "#FFB347", "#A78BFA", "#F472B6",
            "#34D399", "#FBBF24"
        ]

        return GroupBox(title) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(colorChoices, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(hex == "#FFFFFF" ? Color.gray.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(hex == "#FFFFFF" || hex == "#FBBF24" ? .black : .white)
                                .opacity(selectedHex.wrappedValue == hex ? 1 : 0)
                        )
                        .onTapGesture { selectedHex.wrappedValue = hex }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.system(size: 14))
    }
}

#Preview {
    EventDetailView(
        event: CountdownEvent(
            title: "期末考试周",
            emoji: "📝",
            endDate: Calendar.current.date(byAdding: .day, value: 45, to: Date())!,
            category: .academic,
            colorHex: "#5B7FFF"
        )
    )
    .modelContainer(for: CountdownEvent.self, inMemory: true)
}
