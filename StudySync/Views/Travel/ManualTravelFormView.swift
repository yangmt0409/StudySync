import SwiftUI

/// Manual entry form — also handles the "Rail / Train" path since it shares
/// the same shape (minus airline-specific fields).
struct ManualTravelFormView: View {
    @Environment(\.dismiss) private var dismiss
    var initialKind: TravelKind = .flight
    var onSave: (TravelEvent) -> Void

    @State private var kind: TravelKind
    @State private var carrierCode = ""
    @State private var number = ""
    @State private var departureCity = ""
    @State private var departureStation = ""
    @State private var departureStationCode = ""
    @State private var departureTimeLocal = Date().addingTimeInterval(86400)
    @State private var departureTimeZoneID = TimeZone.current.identifier
    @State private var arrivalCity = ""
    @State private var arrivalStation = ""
    @State private var arrivalStationCode = ""
    @State private var arrivalTimeLocal = Date().addingTimeInterval(86400 + 3600)
    @State private var arrivalTimeZoneID = TimeZone.current.identifier
    @State private var seat = ""
    @State private var pnr = ""
    @State private var note = ""

    @State private var showStationPicker = false
    @State private var stationPickerField: StationField = .departure
    enum StationField { case departure, arrival }

    init(initialKind: TravelKind = .flight,
         onSave: @escaping (TravelEvent) -> Void) {
        self.initialKind = initialKind
        self.onSave = onSave
        self._kind = State(initialValue: initialKind)
    }

    var body: some View {
        NavigationStack {
            Form {
                kindSection
                identitySection
                originSection
                destinationSection
                extrasSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(String(localized: "手动输入"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "保存")) { save() }
                        .disabled(!canSave)
                }
            }
            .dismissKeyboardToolbar()
            .sheet(isPresented: $showStationPicker) {
                StationPickerView { station in
                    applyStation(station)
                    showStationPicker = false
                }
            }
        }
    }

    private var kindSection: some View {
        Section(String(localized: "类型")) {
            Picker(selection: $kind) {
                ForEach(TravelKind.allCases) { k in
                    Label {
                        Text(k.label)
                    } icon: {
                        Image(systemName: k.symbolName)
                    }
                    .tag(k)
                }
            } label: { Text(String(localized: "类型")) }
        }
    }

    private var identitySection: some View {
        Section(String(localized: "车次 / 航班号")) {
            HStack {
                TextField(String(localized: "航司代码 / 车次前缀"), text: $carrierCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .frame(maxWidth: 100)
                Divider()
                TextField(String(localized: "号码"), text: $number)
                    .keyboardType(.asciiCapable)
                    .autocorrectionDisabled()
            }
            .onChange(of: number) { _, _ in autoDetectKind() }
        }
    }

    private var originSection: some View {
        Section(String(localized: "出发")) {
            if kind == .highSpeedRail || kind == .train || kind == .intercityTrain {
                HStack {
                    Text(String(localized: "起点站"))
                    Spacer()
                    Button {
                        stationPickerField = .departure
                        showStationPicker = true
                    } label: {
                        Text(departureStation.isEmpty ? String(localized: "选择") : departureStation)
                            .foregroundStyle(departureStation.isEmpty ? Color.blue : .primary)
                    }
                }
            } else {
                TextField(String(localized: "城市"), text: $departureCity)
                TextField(String(localized: "机场 / 车站"), text: $departureStation)
                TextField(String(localized: "代码 (PEK / BJP)"), text: $departureStationCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            }
            DatePicker(String(localized: "起飞 / 发车时间"), selection: $departureTimeLocal)
            TimeZonePicker(zoneID: $departureTimeZoneID, label: String(localized: "起点时区"))
        }
    }

    @ViewBuilder
    private var timeValidationFooter: some View {
        if !number.isEmpty && !isArrivalAfterDeparture {
            Text(String(localized: "到达时间必须晚于起飞 / 发车时间"))
                .font(.system(size: 12))
                .foregroundStyle(.red)
        }
    }

    private var destinationSection: some View {
        Section {
            destinationSectionContent
        } header: {
            Text(String(localized: "到达"))
        } footer: {
            timeValidationFooter
        }
    }

    @ViewBuilder
    private var destinationSectionContent: some View {
            if kind == .highSpeedRail || kind == .train || kind == .intercityTrain {
                HStack {
                    Text(String(localized: "终点站"))
                    Spacer()
                    Button {
                        stationPickerField = .arrival
                        showStationPicker = true
                    } label: {
                        Text(arrivalStation.isEmpty ? String(localized: "选择") : arrivalStation)
                            .foregroundStyle(arrivalStation.isEmpty ? Color.blue : .primary)
                    }
                }
            } else {
                TextField(String(localized: "城市"), text: $arrivalCity)
                TextField(String(localized: "机场 / 车站"), text: $arrivalStation)
                TextField(String(localized: "代码 (YYZ / SHH)"), text: $arrivalStationCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            }
            DatePicker(String(localized: "到达时间"), selection: $arrivalTimeLocal)
            TimeZonePicker(zoneID: $arrivalTimeZoneID, label: String(localized: "终点时区"))
    }

    private var extrasSection: some View {
        Section(String(localized: "可选信息")) {
            TextField(String(localized: "座位 / 车厢"), text: $seat)
                .autocorrectionDisabled()
            TextField(String(localized: "订票号 / PNR"), text: $pnr)
                .autocorrectionDisabled()
            TextField(String(localized: "备注"), text: $note, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    // MARK: - Actions

    private var canSave: Bool {
        !number.isEmpty
            && !departureStation.isEmpty
            && !arrivalStation.isEmpty
            && isArrivalAfterDeparture
    }

    /// Both times are stored as "UTC-packed wall-clock" values, so a simple
    /// `<` comparison correctly catches arrival-before-departure at the wall
    /// level, which is what the user sees.
    private var isArrivalAfterDeparture: Bool {
        arrivalTimeLocal > departureTimeLocal
    }

    private func autoDetectKind() {
        let combined = (carrierCode + number).uppercased()
        if let detected = TravelKind.detect(from: combined), detected != kind {
            kind = detected
        }
    }

    private func applyStation(_ station: RailStations.Station) {
        switch stationPickerField {
        case .departure:
            departureStation = station.nameZh
            departureStationCode = station.code
            departureCity = station.city
            departureTimeZoneID = station.timeZoneID
        case .arrival:
            arrivalStation = station.nameZh
            arrivalStationCode = station.code
            arrivalCity = station.city
            arrivalTimeZoneID = station.timeZoneID
        }
    }

    private func save() {
        Task {
            let importer = ManualTravelImporter()
            let input = ManualTravelInput(
                kind: kind,
                carrierCode: carrierCode.trimmingCharacters(in: .whitespaces),
                number: number.trimmingCharacters(in: .whitespaces),
                departureCity: departureCity,
                departureStation: departureStation,
                departureStationCode: departureStationCode,
                departureTimeLocal: departureTimeLocal,
                departureTimeZoneID: departureTimeZoneID,
                arrivalCity: arrivalCity,
                arrivalStation: arrivalStation,
                arrivalStationCode: arrivalStationCode,
                arrivalTimeLocal: arrivalTimeLocal,
                arrivalTimeZoneID: arrivalTimeZoneID,
                seat: seat.isEmpty ? nil : seat,
                pnr: pnr.isEmpty ? nil : pnr,
                note: note.isEmpty ? nil : note
            )
            if let draft = try? await importer.makeDraft(from: input) {
                onSave(draft)
                dismiss()
            }
        }
    }
}

// MARK: - Timezone Picker

struct TimeZonePicker: View {
    @Binding var zoneID: String
    var label: String

    var body: some View {
        Picker(selection: $zoneID) {
            ForEach(commonZones, id: \.self) { id in
                Text(id).tag(id)
            }
        } label: {
            Text(label)
        }
    }

    private var commonZones: [String] {
        [
            "Asia/Shanghai",      // 中国
            "Asia/Hong_Kong",
            "Asia/Tokyo",
            "Asia/Seoul",
            "Asia/Singapore",
            "Asia/Bangkok",
            "Asia/Dubai",
            "Europe/London",
            "Europe/Paris",
            "Europe/Berlin",
            "America/New_York",
            "America/Toronto",
            "America/Los_Angeles",
            "America/Chicago",
            "Australia/Sydney",
        ]
    }
}

// MARK: - Station Picker

struct StationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    var onPick: (RailStations.Station) -> Void

    private var results: [RailStations.Station] {
        RailStations.search(query)
    }

    var body: some View {
        NavigationStack {
            List(results) { station in
                Button {
                    onPick(station)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(station.nameZh)
                                .font(.system(size: 15, weight: .semibold))
                            Text(station.code)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(.secondary.opacity(0.15), in: Capsule())
                        }
                        Text(station.nameEn)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $query, prompt: String(localized: "搜索车站"))
            .navigationTitle(String(localized: "选择车站"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                }
            }
        }
    }
}
