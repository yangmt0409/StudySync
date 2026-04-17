import Foundation
import SwiftUI

// MARK: - App Tab Definition

enum AppTab: String, CaseIterable, Identifiable, Codable {
    case schedule
    case todo
    case focus
    case countdown
    case studyGoal
    case social
    case tools
    case gradeCalc
    case aiMonitor
    case settings
    case about

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .schedule:  return L10n.tabSchedule
        case .todo:      return L10n.todoTitle
        case .focus:     return L10n.focusTitle
        case .countdown: return L10n.tabCountdown
        case .studyGoal: return L10n.goalTitle
        case .social:    return L10n.socialTitle
        case .tools:     return L10n.tools
        case .gradeCalc: return L10n.gradeCalcTitle
        case .aiMonitor: return L10n.aiMonitor
        case .settings:  return L10n.tabSettings
        case .about:     return L10n.about
        }
    }

    var systemImage: String {
        switch self {
        case .schedule:  return "calendar"
        case .todo:      return "checklist"
        case .focus:     return "timer"
        case .countdown: return "hourglass"
        case .studyGoal: return "target"
        case .social:    return "person.2.fill"
        case .tools:     return "wrench.and.screwdriver.fill"
        case .gradeCalc: return "function"
        case .aiMonitor: return "cpu"
        case .settings:  return "gearshape.fill"
        case .about:     return "info.circle.fill"
        }
    }
}

// MARK: - Tab Manager

final class TabManager {
    static let shared = TabManager()

    private let orderKey = "tabOrder"
    private let mainCountKey = "tabMainCount"
    private let defaults = SyncedDefaults.shared

    /// Maximum tabs shown in the tab bar (rest go to More).
    /// iOS tab bar shows at most 5 icons — 1 reserved for our "More" tab → max 4.
    static let maxMainTabs = 4

    /// Default tab order
    static let defaultOrder: [AppTab] = AppTab.allCases

    private init() {}

    // MARK: - Tab Order

    /// Tabs pinned to the tail in this exact order. Cannot be reordered.
    /// .settings is always second-to-last, .about is always last.
    static let pinnedTailTabs: [AppTab] = [.settings, .about]

    /// The full ordered list of tabs
    var tabOrder: [AppTab] {
        get {
            guard let data = defaults.data(forKey: orderKey),
                  let saved = try? JSONDecoder().decode([AppTab].self, from: data) else {
                return Self.defaultOrder
            }
            // Ensure all tabs are present (in case new tabs were added in an update)
            var result = saved
            for tab in AppTab.allCases where !result.contains(tab) {
                result.append(tab)
            }
            // Lock pinned tail tabs at the end in order
            result.removeAll { Self.pinnedTailTabs.contains($0) }
            result.append(contentsOf: Self.pinnedTailTabs)
            return result
        }
        set {
            var order = newValue
            order.removeAll { Self.pinnedTailTabs.contains($0) }
            order.append(contentsOf: Self.pinnedTailTabs)
            if let data = try? JSONEncoder().encode(order) {
                defaults.set(data, forKey: orderKey)
            }
        }
    }

    /// How many tabs are shown in the main tab bar
    var mainTabCount: Int {
        get {
            let saved = defaults.integer(forKey: mainCountKey)
            return saved > 0 ? min(saved, Self.maxMainTabs) : Self.maxMainTabs
        }
        set {
            defaults.set(max(2, min(newValue, Self.maxMainTabs)), forKey: mainCountKey)
        }
    }

    /// Tabs shown directly in the tab bar (schedule always first, pinned tail tabs never here)
    var mainTabs: [AppTab] {
        var tabs = Array(tabOrder.prefix(mainTabCount))
        tabs.removeAll { $0 == .schedule || Self.pinnedTailTabs.contains($0) }
        tabs.insert(.schedule, at: 0)
        return Array(tabs.prefix(Self.maxMainTabs))
    }

    /// Tabs shown inside the "More" tab (schedule never here, pinned tail tabs always at end in order)
    var moreTabs: [AppTab] {
        var tabs = Array(tabOrder.dropFirst(mainTabCount)).filter { $0 != .schedule }
        // Remove and re-append pinned tail tabs in their fixed order
        tabs.removeAll { Self.pinnedTailTabs.contains($0) }
        tabs.append(contentsOf: Self.pinnedTailTabs)
        return tabs
    }

    /// Move a tab from More to the main bar (insert at end of main tabs)
    func promoteTab(_ tab: AppTab) {
        guard !Self.pinnedTailTabs.contains(tab) else { return }
        var order = tabOrder
        guard let idx = order.firstIndex(of: tab), idx >= mainTabCount else { return }
        order.remove(at: idx)
        order.insert(tab, at: mainTabCount)
        tabOrder = order
        mainTabCount = mainTabCount + 1
    }

    /// Move a tab from the main bar to More (insert at start of more tabs)
    func demoteTab(_ tab: AppTab) {
        guard !Self.pinnedTailTabs.contains(tab) else { return }
        guard mainTabCount > 2 else { return } // Keep at least 2 main tabs
        var order = tabOrder
        guard let idx = order.firstIndex(of: tab), idx < mainTabCount else { return }
        order.remove(at: idx)
        order.insert(tab, at: mainTabCount - 1)
        tabOrder = order
        mainTabCount = mainTabCount - 1
    }

    /// Move a tab within main or within more
    func moveTab(from source: IndexSet, to destination: Int) {
        var order = tabOrder
        order.move(fromOffsets: source, toOffset: destination)
        tabOrder = order
    }

    /// Reset to default layout
    func resetToDefault() {
        defaults.removeObject(forKey: orderKey)
        defaults.removeObject(forKey: mainCountKey)
    }
}
