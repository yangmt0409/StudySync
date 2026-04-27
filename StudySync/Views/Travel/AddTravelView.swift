import SwiftUI
import SwiftData

/// Entry point for adding a travel event. Presents a picker of import methods;
/// each method pushes its own sub-view and ultimately saves to SwiftData.
struct AddTravelView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var activeMethod: ImportMethod?

    enum ImportMethod: String, CaseIterable, Identifiable {
        case manual, flightAPI, rail, wallet, calendar, barcode, pdf, shareIntake
        var id: String { rawValue }

        var title: String {
            switch self {
            case .manual:        return String(localized: "手动输入")
            case .flightAPI:     return String(localized: "航班号查询")
            case .rail:          return String(localized: "高铁 / 火车")
            case .wallet:        return String(localized: "从 Apple Wallet 导入")
            case .calendar:      return String(localized: "从日历导入")
            case .barcode:       return String(localized: "扫描条码")
            case .pdf:           return String(localized: "从 PDF 导入")
            case .shareIntake:   return String(localized: "粘贴文本解析")
            }
        }

        var subtitle: String {
            switch self {
            case .manual:        return String(localized: "填写基本信息")
            case .flightAPI:     return String(localized: "输入航班号自动补全")
            case .rail:          return String(localized: "查询车次 / 手动输入")
            case .wallet:        return String(localized: "读取 Wallet 登机牌")
            case .calendar:      return String(localized: "自动识别日历中的行程")
            case .barcode:       return String(localized: "扫描登机牌 / 车票条码")
            case .pdf:           return String(localized: "解析 PDF 电子票")
            case .shareIntake:   return String(localized: "粘贴邮件 / 携程分享内容")
            }
        }

        var symbol: String {
            switch self {
            case .manual:       return "square.and.pencil"
            case .flightAPI:    return "airplane.circle"
            case .rail:         return "tram.fill"
            case .wallet:       return "wallet.pass.fill"
            case .calendar:     return "calendar"
            case .barcode:      return "barcode.viewfinder"
            case .pdf:          return "doc.fill"
            case .shareIntake:  return "doc.text"
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ImportMethod.allCases) { method in
                        Button {
                            activeMethod = method
                        } label: {
                            methodRow(method)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(String(localized: "选择添加方式"))
                } footer: {
                    Text(String(localized: "以 Apple Wallet 或扫描登机牌条码导入最准确，查询航班号其次。"))
                }
            }
            .navigationTitle(String(localized: "添加行程"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                }
            }
            .sheet(item: $activeMethod) { method in
                destination(for: method)
            }
        }
    }

    @ViewBuilder
    private func destination(for method: ImportMethod) -> some View {
        switch method {
        case .manual, .rail:
            ManualTravelFormView(
                initialKind: method == .rail ? .highSpeedRail : .flight,
                onSave: { saveDraft($0) }
            )
        case .flightAPI:
            FlightAPILookupView(onSave: { saveDraft($0) })
        case .wallet:
            WalletImportView(onSave: { saveDraft($0) })
        case .calendar:
            CalendarImportView(onSave: { saveDraft($0) })
        case .barcode:
            BarcodeImportView(onSave: { saveDraft($0) })
        case .pdf:
            PDFImportView(onSave: { saveDraft($0) })
        case .shareIntake:
            PasteImportView(onSave: { saveDraft($0) })
        }
    }

    private func methodRow(_ method: ImportMethod) -> some View {
        HStack(spacing: 14) {
            Image(systemName: method.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 36, height: 36)
                .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(method.title)
                    .font(.system(size: 15, weight: .semibold))
                Text(method.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private func saveDraft(_ draft: TravelEvent) {
        modelContext.insert(draft)
        try? modelContext.save()
        TravelEventSyncService.shared.pushEvent(draft)
        Task { await TravelReminderScheduler.shared.scheduleReminders(for: draft) }
        dismiss()
    }
}
