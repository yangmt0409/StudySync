import SwiftUI
import SwiftData
import FirebaseAuth

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [UserSettings]

    @Environment(\.locale) private var locale

    @State private var showingPaywall = false
    @State private var showingHomeCityPicker = false
    @State private var showingStudyCityPicker = false
    @State private var showingRestartAlert = false
    @State private var pendingHomeTzId: String?
    @State private var pendingHomeName: String?
    @State private var pendingStudyTzId: String?
    @State private var pendingStudyName: String?

    private var store: StoreManager { .shared }
    private var calendarManager: CalendarManager { .shared }

    private var isEnglish: Bool {
        locale.language.languageCode?.identifier == "en"
    }

    private func localizedCityName(for timeZoneId: String, storedName: String) -> String {
        // Match by stored name first (handles cities sharing same timeZoneId)
        if let city = CityDatabase.allCities.first(where: {
            $0.cityName == storedName || $0.englishName == storedName
        }) {
            return isEnglish ? city.englishName : city.cityName
        }
        return storedName
    }

    private var settings: UserSettings {
        if let existing = settingsArray.first {
            return existing
        }
        let newSettings = UserSettings()
        modelContext.insert(newSettings)
        return newSettings
    }


    var body: some View {
        NavigationStack {
            Form {
                // Pro 状态
                Section {
                    if store.isPro {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.orange)
                            Text("StudySync Pro")  // brand name, no localize
                                .font(SSFont.bodySemibold)
                            Spacer()
                            Text(L10n.proActivated)
                                .font(SSFont.chipLabel)
                                .foregroundStyle(.green)
                        }
                    } else {
                        Button {
                            showingPaywall = true
                        } label: {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.upgradePro)
                                        .font(SSFont.bodySemibold)
                                        .foregroundStyle(.primary)
                                    Text(L10n.proFeaturesDesc)
                                        .font(SSFont.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(SSFont.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                // 城市设置
                Section {
                    Button {
                        showingHomeCityPicker = true
                    } label: {
                        HStack {
                            Label(L10n.homeCity, systemImage: "house.fill")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(localizedCityName(for: settings.homeTimeZoneId, storedName: settings.homeCityName))
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(SSFont.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Button {
                        showingStudyCityPicker = true
                    } label: {
                        HStack {
                            Label(L10n.studyCity, systemImage: "mappin.circle.fill")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(localizedCityName(for: settings.studyTimeZoneId, storedName: settings.studyCityName))
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(SSFont.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } header: {
                    Text(L10n.citySettings)
                } footer: {
                    Text(L10n.cityFooter)
                }

                // 日程设置
                Section {
                    Picker(L10n.displayRange, selection: Binding(
                        get: { calendarManager.calendarDayRange },
                        set: { calendarManager.calendarDayRange = $0 }
                    )) {
                        Text(L10n.days3).tag(3)
                        Text(L10n.days5).tag(5)
                        Text(L10n.days7).tag(7)
                        Text(L10n.days14).tag(14)
                        Text(L10n.days30).tag(30)
                    }

                    Toggle(L10n.showFinishedEvents, isOn: Binding(
                        get: { calendarManager.showFinishedEvents },
                        set: { calendarManager.showFinishedEvents = $0 }
                    ))

                    Toggle(L10n.showAllDayEvents, isOn: Binding(
                        get: { calendarManager.showAllDayEvents },
                        set: { calendarManager.showAllDayEvents = $0 }
                    ))
                } header: {
                    Text(L10n.scheduleSection)
                } footer: {
                    Text(L10n.scheduleFooter)
                }

                // Deadline 设置
                Section {
                    Toggle(L10n.dlLavaEffect, isOn: Binding(
                        get: { UrgencyEngine.shared.lavaEffectEnabled },
                        set: { UrgencyEngine.shared.lavaEffectEnabled = $0 }
                    ))

                    if UrgencyEngine.shared.lavaEffectEnabled {
                        Toggle(L10n.dlGlobalBorder, isOn: Binding(
                            get: { UrgencyEngine.shared.globalBorderEnabled },
                            set: { UrgencyEngine.shared.globalBorderEnabled = $0 }
                        ))

                        Toggle(L10n.dlInfectNearby, isOn: Binding(
                            get: { UrgencyEngine.shared.infectionEnabled },
                            set: { UrgencyEngine.shared.infectionEnabled = $0 }
                        ))

                        Picker(L10n.dlUrgencyWindow, selection: Binding(
                            get: { UrgencyEngine.shared.urgencyWindowHours },
                            set: { UrgencyEngine.shared.urgencyWindowHours = $0 }
                        )) {
                            Text(L10n.dlWindow1h).tag(1.0)
                            Text(L10n.dlWindow3h).tag(3.0)
                            Text(L10n.dlWindow6h).tag(6.0)
                            Text(L10n.dlWindow10h).tag(10.0)
                            Text(L10n.dlWindow12h).tag(12.0)
                            Text(L10n.dlWindow24h).tag(24.0)
                        }
                    }
                } header: {
                    Text(L10n.deadline)
                } footer: {
                    Text(L10n.dlSettingsFooter)
                }

                // Live Activity 设置
                Section {
                    Toggle(L10n.laEnabled, isOn: Binding(
                        get: { LiveActivityManager.shared.liveActivityEnabled },
                        set: { LiveActivityManager.shared.liveActivityEnabled = $0 }
                    ))

                    if LiveActivityManager.shared.liveActivityEnabled {
                        Picker(L10n.laLeadTime, selection: Binding(
                            get: { LiveActivityManager.shared.liveActivityLeadMinutes },
                            set: { LiveActivityManager.shared.liveActivityLeadMinutes = $0 }
                        )) {
                            Text(L10n.laLead15).tag(15)
                            Text(L10n.laLead30).tag(30)
                            Text(L10n.laLead60).tag(60)
                        }

                        Picker(L10n.laOverdueTimeout, selection: Binding(
                            get: { LiveActivityManager.shared.overdueTimeoutMinutes },
                            set: { LiveActivityManager.shared.overdueTimeoutMinutes = $0 }
                        )) {
                            Text(L10n.laTimeout5).tag(5)
                            Text(L10n.laTimeout10).tag(10)
                            Text(L10n.laTimeout30).tag(30)
                        }
                    }
                } header: {
                    Text(L10n.laLiveActivity)
                } footer: {
                    Text(L10n.laSettingsFooter)
                }

                // iCloud 同步
                Section {
                    Toggle(isOn: Binding(
                        get: { iCloudSyncManager.shared.isEnabled },
                        set: { newValue in
                            iCloudSyncManager.shared.isEnabled = newValue
                            showingRestartAlert = true
                        }
                    )) {
                        HStack {
                            Image(systemName: "icloud.fill")
                                .foregroundStyle(.blue)
                            Text(L10n.iCloudSync)
                        }
                    }
                } header: {
                    Text(L10n.iCloudSync)
                } footer: {
                    Text(L10n.iCloudSyncFooter)
                }

                // 同步状态
                Section {
                    syncStatusRow(
                        icon: "icloud.fill",
                        iconColor: .blue,
                        title: "iCloud",
                        status: iCloudSyncManager.shared.isEnabled,
                        detail: L10n.syncICloudItems
                    )
                    syncStatusRow(
                        icon: "person.crop.circle.badge.checkmark",
                        iconColor: SSColor.brand,
                        title: "Firebase",
                        status: AuthService.shared.isAuthenticated,
                        statusLabel: AuthService.shared.isAuthenticated ? L10n.syncEnabled : L10n.syncNotLoggedIn,
                        detail: L10n.syncFirebaseItems
                    )
                } header: {
                    Text(L10n.syncStatus)
                }

                // Tab 自定义
                Section {
                    NavigationLink {
                        TabCustomizationView()
                    } label: {
                        Label(L10n.tabCustomization, systemImage: "square.grid.2x2")
                    }
                } header: {
                    Text(L10n.tabCustomization)
                } footer: {
                    Text(L10n.tabCustomizationFooter)
                }

                // 显示设置
                Section(L10n.displaySettings) {
                    Toggle(L10n.showExpired, isOn: Binding(
                        get: { settings.showExpiredEvents },
                        set: {
                            settings.showExpiredEvents = $0
                            UserSettingsSyncService.shared.pushSettings(settings)
                        }
                    ))

                    Picker(L10n.defaultCategory, selection: Binding(
                        get: { settings.defaultCategory },
                        set: {
                            settings.defaultCategory = $0
                            UserSettingsSyncService.shared.pushSettings(settings)
                        }
                    )) {
                        ForEach(EventCategory.allCases) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                }

                // 关于
                Section(L10n.about) {
                    HStack {
                        Text(L10n.version)
                        Spacer()
                        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                        Text(verbatim: "\(version) (\(build))")
                            .foregroundStyle(.secondary)
                            .font(SSFont.mono)
                    }

                    HStack {
                        Text(L10n.developer)
                        Spacer()
                        Text("Maitong Yang")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(L10n.tabSettings)
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .alert(L10n.iCloudSyncRestartTitle, isPresented: $showingRestartAlert) {
                Button(L10n.done) { }
            } message: {
                Text(L10n.iCloudSyncRestartMessage)
            }
            .sheet(isPresented: $showingHomeCityPicker, onDismiss: {
                if let tzId = pendingHomeTzId, let name = pendingHomeName {
                    if let existing = settingsArray.first {
                        existing.homeTimeZoneId = tzId
                        existing.homeCityName = name
                        try? modelContext.save()
                        UserSettingsSyncService.shared.pushSettings(existing)
                    }
                    pendingHomeTzId = nil
                    pendingHomeName = nil
                }
            }) {
                CityPickerView(title: L10n.homeCity) { tzId, cityName in
                    pendingHomeTzId = tzId
                    pendingHomeName = cityName
                }
            }
            .sheet(isPresented: $showingStudyCityPicker, onDismiss: {
                if let tzId = pendingStudyTzId, let name = pendingStudyName {
                    if let existing = settingsArray.first {
                        existing.studyTimeZoneId = tzId
                        existing.studyCityName = name
                        try? modelContext.save()
                        UserSettingsSyncService.shared.pushSettings(existing)
                    }
                    pendingStudyTzId = nil
                    pendingStudyName = nil
                }
            }) {
                CityPickerView(title: L10n.studyCity) { tzId, cityName in
                    pendingStudyTzId = tzId
                    pendingStudyName = cityName
                }
            }
        }
    }

    // MARK: - Sync Status Row

    private func syncStatusRow(
        icon: String,
        iconColor: Color,
        title: String,
        status: Bool,
        statusLabel: String? = nil,
        detail: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(SSFont.bodyMedium)
                    Circle()
                        .fill(status ? .green : Color(.systemGray3))
                        .frame(width: 8, height: 8)
                    Text(statusLabel ?? (status ? L10n.syncEnabled : L10n.syncDisabled))
                        .font(SSFont.badge)
                        .foregroundStyle(status ? .green : .secondary)
                }
                Text(detail)
                    .font(SSFont.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - App Icon

    private var currentIconName: String? {
        UIApplication.shared.alternateIconName
    }

    private func changeAppIcon(to icon: AppIconOption) {
        let name = icon.iconName
        UIApplication.shared.setAlternateIconName(name) { error in
            if error == nil {
                HapticManager.success()
            }
        }
    }
}

// MARK: - App Icon Options

enum AppIconOption: String, CaseIterable, Identifiable {
    case `default` = "Default"
    case ocean = "Ocean"
    case sunset = "Sunset"
    case forest = "Forest"
    case midnight = "Midnight"
    case coral = "Coral"

    var id: String { rawValue }

    var iconName: String? {
        self == .default ? nil : rawValue
    }

    var displayName: String {
        switch self {
        case .default: return L10n.iconDefault
        case .ocean: return L10n.iconOcean
        case .sunset: return L10n.iconSunset
        case .forest: return L10n.iconForest
        case .midnight: return L10n.iconMidnight
        case .coral: return L10n.iconCoral
        }
    }

    var colorHex: String {
        switch self {
        case .default: return "#5B7FFF"
        case .ocean: return "#0EA5E9"
        case .sunset: return "#F97316"
        case .forest: return "#22C55E"
        case .midnight: return "#1E293B"
        case .coral: return "#F472B6"
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: UserSettings.self, inMemory: true)
}
