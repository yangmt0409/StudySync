import SwiftUI
import PassKit
import EventKit
import UniformTypeIdentifiers

// MARK: - Wallet Import

/// "Import from Wallet" page.
///
/// Why this is now an instruction page (not a pass list): `PKPassLibrary`
/// requires the `com.apple.developer.pass-type-identifiers` entitlement —
/// only granted by Apple on review for first-party travel apps. Without
/// it, `PKPassLibrary().passes()` always returns an empty array (regardless
/// of how many boarding passes the user actually has in Wallet).
///
/// Instead we registered StudySync as a handler for the `com.apple.pkpass`
/// UTI in Info.plist. The user shares the pass FROM Wallet TO us via the
/// system share sheet; the URL lands at MainTabView's `.onOpenURL`.
/// This page just walks the user through that flow.
struct WalletImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass
    var onSave: (TravelEvent) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SSSpacing.xxxl) {
                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [SSColor.brand, Color(hex: "#A78BFA")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, SSSpacing.xxxl)

                    VStack(spacing: SSSpacing.md) {
                        Text(String(localized: "从 Apple Wallet 导入"))
                            .font(.system(size: 22, weight: .bold))
                        Text(String(localized: "请按以下步骤把登机牌发给 StudySync"))
                            .font(SSFont.secondary)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: SSSpacing.lgXl) {
                        stepRow(
                            number: 1,
                            title: String(localized: "打开 Apple Wallet"),
                            desc: String(localized: "在 Wallet 里找到要导入的登机牌或车票")
                        )
                        stepRow(
                            number: 2,
                            title: String(localized: "点击右上角 ⋯ 菜单"),
                            desc: String(localized: "选择「分享」或「分享 Pass」")
                        )
                        stepRow(
                            number: 3,
                            title: String(localized: "在分享面板里选 StudySync"),
                            desc: String(localized: "App 会自动跳转回来并完成导入")
                        )
                    }
                    .padding(.horizontal, SSSpacing.xxl)

                    Text(String(localized: "提示：如果分享面板里没有 StudySync，先把 Pass 用「存储到文件」保存到 iCloud Drive，再到「文件」app 里点开 → 选 StudySync 打开。"))
                        .font(SSFont.footnote)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SSSpacing.xxxl)
                        .padding(.top, SSSpacing.md)

                    Spacer(minLength: 40)
                }
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(String(localized: "从 Wallet 导入"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "完成")) { dismiss() }
                }
            }
        }
    }

    private func stepRow(number: Int, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: SSSpacing.lgXl) {
            Text("\(number)")
                .font(SSFont.bodySemibold)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(SSColor.brand))

            VStack(alignment: .leading, spacing: SSSpacing.xs) {
                Text(title)
                    .font(SSFont.bodySmallSemibold)
                Text(desc)
                    .font(SSFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

// MARK: - Calendar Import

struct CalendarImportView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (TravelEvent) -> Void

    @State private var isSearching = true
    @State private var candidates: [EKEvent] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    ProgressView {
                        Text(String(localized: "扫描日历中…"))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if candidates.isEmpty {
                    emptyState
                } else {
                    List(candidates, id: \.eventIdentifier) { event in
                        Button { pick(event) } label: {
                            candidateRow(event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(String(localized: "从日历导入"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                }
            }
            .task { await search() }
            .alert(String(localized: "错误"),
                   isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: SSSpacing.lg) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(String(localized: "日历中没有检测到行程"))
                .font(.headline)
            Text(String(localized: "我们只识别航班号 / 车次 / 机场 / 车站等关键字。"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func candidateRow(_ event: EKEvent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.title ?? "")
                .font(SSFont.bodySmallSemibold)
                .lineLimit(1)
            HStack(spacing: SSSpacing.sm) {
                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(event.startDate.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.tertiary)
            }
            .font(.system(size: 11))
        }
    }

    private func search() async {
        isSearching = true
        defer { isSearching = false }
        do {
            let importer = CalendarTravelImporter()
            candidates = try await importer.findCandidates()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pick(_ event: EKEvent) {
        Task {
            do {
                let importer = CalendarTravelImporter()
                let draft = try await importer.makeDraft(from: event)
                onSave(draft)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Barcode Import

struct BarcodeImportView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (TravelEvent) -> Void
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            TravelBarcodeScanner { payload, format in
                Task {
                    do {
                        let importer = BarcodeTravelImporter()
                        let draft = try await importer.makeDraft(
                            from: .init(payload: payload, format: format)
                        )
                        onSave(draft)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .navigationTitle(String(localized: "扫描条码"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                }
            }
            .alert(String(localized: "无法识别"),
                   isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}

// MARK: - PDF Import

struct PDFImportView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (TravelEvent) -> Void
    @State private var errorMessage: String?
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: SSSpacing.xl) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                Text(String(localized: "从 PDF 电子票导入"))
                    .font(.headline)
                Text(String(localized: "支持大多数航空公司 / 12306 的 PDF 电子客票。"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button {
                    isImporting = true
                } label: {
                    Label(String(localized: "选择 PDF 文件"), systemImage: "folder")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(SSOpacity.lightTint), in: RoundedRectangle(cornerRadius: SSRadius.fieldCard))
                }
                .padding(.horizontal, SSSpacing.xxxl)
                .padding(.top, SSSpacing.lg)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
            .navigationTitle(String(localized: "PDF 导入"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    importPDF(at: url)
                case .failure(let err):
                    errorMessage = err.localizedDescription
                }
            }
            .alert(String(localized: "解析失败"),
                   isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func importPDF(at url: URL) {
        // Files from fileImporter are security-scoped. We must hold access for
        // the entire read — which happens inside the async Task. Releasing in a
        // `defer` at the enclosing-function level would drop the scope before
        // the Task runs, so acquire/release must both happen inside the Task.
        Task {
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            do {
                let importer = PDFTravelImporter()
                let draft = try await importer.makeDraft(from: .init(fileURL: url))
                onSave(draft)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Paste / Share Intake

struct PasteImportView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (TravelEvent) -> Void
    @State private var text: String = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 200)
                        .autocorrectionDisabled()
                } header: {
                    Text(String(localized: "粘贴邮件 / 分享文本"))
                } footer: {
                    Text(String(localized: "支持携程 / 12306 / 邮件行程提醒等，自动识别航班号 / 车次。"))
                }
                Button {
                    parse()
                } label: {
                    Label(String(localized: "解析"), systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .disabled(text.isEmpty)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(String(localized: "粘贴导入"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                }
            }
            .dismissKeyboardToolbar()
            .alert(String(localized: "无法识别"),
                   isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func parse() {
        let service = ShareIntakeService()
        let result = service.parse(text)
        switch result {
        case .draft(let draft):
            onSave(draft)
            dismiss()
        case .designator(let carrier, let number, let kind, let date):
            // Build a minimal draft from detected designator; user can flesh out later
            let e = TravelEvent(
                kind: kind,
                carrierCode: carrier,
                number: number,
                departureTimeLocal: date ?? Date().addingTimeInterval(86400),
                arrivalTimeLocal: (date ?? Date().addingTimeInterval(86400)).addingTimeInterval(3600),
                importSource: .shareExtension
            )
            onSave(e)
            dismiss()
        case .unknown:
            errorMessage = String(localized: "未能从文本中识别航班或车次信息")
        }
    }
}
