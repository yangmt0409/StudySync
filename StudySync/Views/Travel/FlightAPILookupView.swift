import SwiftUI

/// Lookup-by-flight-number flow. User enters `CA981` + date, we fire a query
/// against the currently-selected `FlightLookupProvider` (AeroDataBox by
/// default, AviationStack as an alternative), show a candidate list, user
/// picks, we persist.
struct FlightAPILookupView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (TravelEvent) -> Void

    @State private var iataNumber: String = ""
    @State private var flightDate: Date = Date().addingTimeInterval(86400)
    @State private var isSearching = false
    @State private var candidates: [FlightLookupResult] = []
    @State private var errorMessage: String?
    @State private var quotaExceeded = false
    @State private var showAPIKeyEntry = false
    @State private var selectedProvider: FlightProviderKind = FlightProviderRegistry.selected

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.blue)
                        TextField(String(localized: "航班号 (如 CA981)"), text: $iataNumber)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }
                    DatePicker(String(localized: "起飞日期"),
                               selection: $flightDate,
                               displayedComponents: [.date])
                    Button {
                        Task { await runLookup() }
                    } label: {
                        HStack {
                            if isSearching {
                                ProgressView()
                            } else {
                                Image(systemName: "magnifyingglass")
                            }
                            Text(String(localized: "查询"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(iataNumber.count < 3 || isSearching)
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker(String(localized: "数据来源"), selection: $selectedProvider) {
                            ForEach(FlightProviderKind.allCases, id: \.self) { kind in
                                Text(kind.displayName).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedProvider) { _, new in
                            FlightProviderRegistry.selected = new
                            candidates = []
                            errorMessage = nil
                        }
                        Text(selectedProvider.footerBlurb)
                        Button(String(localized: "配置 API Key")) {
                            showAPIKeyEntry = true
                        }
                        .font(.system(size: 12))
                    }
                }

                if let err = errorMessage {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundStyle(quotaExceeded ? .orange : .red)
                            if quotaExceeded {
                                // Prominent call-to-action: shared key is out;
                                // the only fix is the user supplies their own.
                                Button {
                                    showAPIKeyEntry = true
                                } label: {
                                    Label(String(localized: "配置我自己的 API Key"),
                                          systemImage: "key.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                            }
                        }
                    }
                }

                if !candidates.isEmpty {
                    Section(String(localized: "查询结果")) {
                        ForEach(candidates.indices, id: \.self) { idx in
                            candidateRow(candidates[idx])
                                .onTapGesture { pick(candidates[idx]) }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(String(localized: "航班号查询"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                }
            }
            .dismissKeyboardToolbar()
            .sheet(isPresented: $showAPIKeyEntry) {
                FlightProviderKeyEntryView(provider: selectedProvider)
            }
        }
    }

    // MARK: - Candidate row

    @ViewBuilder
    private func candidateRow(_ flight: FlightLookupResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(flight.flightIATA ?? flight.flightNumber ?? "—")
                    .font(.system(size: 15, weight: .bold))
                if let airline = flight.airlineName {
                    Text(airline)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let status = flight.status {
                    Text(status.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.secondary.opacity(0.15), in: Capsule())
                }
            }
            HStack {
                Label {
                    Text(flight.departure?.iata ?? "—")
                } icon: {
                    Image(systemName: "airplane.departure").font(.system(size: 10))
                }
                Text("→")
                    .foregroundStyle(.secondary)
                Label {
                    Text(flight.arrival?.iata ?? "—")
                } icon: {
                    Image(systemName: "airplane.arrival").font(.system(size: 10))
                }
            }
            .font(.system(size: 12))
            if let scheduled = flight.departure?.scheduled {
                Text(scheduled.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    private func runLookup() async {
        errorMessage = nil
        quotaExceeded = false
        candidates = []
        isSearching = true
        defer { isSearching = false }
        do {
            let importer = FlightAPIImporter()
            let results = try await importer.lookupCandidates(
                iataNumber: iataNumber.trimmingCharacters(in: .whitespaces),
                flightDate: flightDate
            )
            if results.isEmpty {
                errorMessage = TravelImportError.notFound.errorDescription
            } else {
                candidates = results
            }
        } catch let error as FlightLookupError {
            errorMessage = error.errorDescription
            switch error {
            case .missingAPIKey:
                showAPIKeyEntry = true
            case .quotaExceeded:
                quotaExceeded = true
            default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pick(_ flight: FlightLookupResult) {
        do {
            let event = try TravelImporterMapping.travelEvent(from: flight, source: .flightAPI)
            onSave(event)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - API Key Entry

/// Provider-parameterized key-entry sheet. The same view handles AviationStack
/// and AeroDataBox — only the display name + signup URL differ.
struct FlightProviderKeyEntryView: View {
    let provider: FlightProviderKind
    @Environment(\.dismiss) private var dismiss
    @State private var key: String = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(String(localized: "输入 API Key"), text: $key)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("\(provider.displayName) API Key")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(provider.footerBlurb)
                        if let url = provider.signupURL {
                            Link(String(localized: "前往注册"), destination: url)
                                .font(.system(size: 13))
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "配置 API Key"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "保存")) {
                        isSaving = true
                        Task {
                            await FlightProviderRegistry.provider(for: provider).setAPIKey(key)
                            isSaving = false
                            dismiss()
                        }
                    }
                    .disabled(key.isEmpty || isSaving)
                }
            }
            .dismissKeyboardToolbar()
        }
    }
}
