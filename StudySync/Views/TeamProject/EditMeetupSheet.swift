import SwiftUI
import MapKit

struct EditMeetupSheet: View {
    let meetup: MeetupSession
    @Bindable var viewModel: TeamProjectViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var meetupTime: Date

    // Place editing
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedPlace: MKMapItem?
    @State private var isSearching = false
    @State private var isChangingPlace = false

    // Effective place values (original or newly selected)
    private var effectivePlaceName: String {
        selectedPlace?.name ?? meetup.placeName
    }
    private var effectivePlaceAddress: String {
        selectedPlace?.placemark.formattedAddress ?? meetup.placeAddress
    }
    private var effectiveCoord: CLLocationCoordinate2D {
        selectedPlace?.placemark.coordinate ?? CLLocationCoordinate2D(
            latitude: meetup.placeLatitude,
            longitude: meetup.placeLongitude
        )
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init(meetup: MeetupSession, viewModel: TeamProjectViewModel) {
        self.meetup = meetup
        self.viewModel = viewModel
        _title = State(initialValue: meetup.title)
        _meetupTime = State(initialValue: meetup.meetupTime)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SSSpacing.xxl) {

                    // MARK: - Title
                    VStack(alignment: .leading, spacing: SSSpacing.sm) {
                        Text(L10n.meetupTitleLabel)
                            .font(SSFont.caption)
                            .foregroundStyle(.secondary)
                        TextField(L10n.meetupTitlePlaceholder, text: $title)
                            .font(SSFont.body)
                            .padding(SSSpacing.xl)
                            .background(
                                RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                                    .fill(SSColor.backgroundCard)
                            )
                    }

                    // MARK: - Time
                    VStack(alignment: .leading, spacing: SSSpacing.sm) {
                        Text(L10n.meetupTimeLabel)
                            .font(SSFont.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $meetupTime, in: Date()...)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(SSSpacing.xl)
                            .background(
                                RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                                    .fill(SSColor.backgroundCard)
                            )
                    }

                    // MARK: - Place
                    VStack(alignment: .leading, spacing: SSSpacing.sm) {
                        HStack {
                            Text(L10n.meetupPlaceLabel)
                                .font(SSFont.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if !isChangingPlace {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isChangingPlace = true
                                    }
                                } label: {
                                    Text(L10n.meetupChangePlace)
                                        .font(SSFont.caption)
                                        .foregroundStyle(SSColor.meetup)
                                }
                            }
                        }

                        // Current / selected place card
                        HStack(spacing: SSSpacing.md) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(SSColor.meetup)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(effectivePlaceName)
                                    .font(SSFont.bodyMedium)
                                if !effectivePlaceAddress.isEmpty {
                                    Text(effectivePlaceAddress)
                                        .font(SSFont.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .padding(SSSpacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                                .fill(Color.green.opacity(0.08))
                        )

                        // Search to change place
                        if isChangingPlace {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField(L10n.meetupPlaceSearch, text: $searchText)
                                    .font(SSFont.body)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .onSubmit { searchPlaces() }
                                    .onChange(of: searchText) { _, newValue in
                                        if newValue.count >= 2 {
                                            searchPlaces()
                                        }
                                    }

                                if !searchText.isEmpty {
                                    Button {
                                        searchText = ""
                                        searchResults = []
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(SSSpacing.xl)
                            .background(
                                RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                                    .fill(SSColor.backgroundCard)
                            )

                            // Search results
                            if !searchResults.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(searchResults, id: \.self) { item in
                                        Button {
                                            selectedPlace = item
                                            searchText = ""
                                            searchResults = []
                                            isChangingPlace = false
                                            HapticEngine.shared.selection()
                                        } label: {
                                            HStack(spacing: SSSpacing.md) {
                                                Image(systemName: "mappin")
                                                    .foregroundStyle(.secondary)
                                                    .frame(width: 20)
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(item.name ?? "")
                                                        .font(SSFont.body)
                                                        .foregroundStyle(.primary)
                                                    if let address = item.placemark.formattedAddress {
                                                        Text(address)
                                                            .font(SSFont.caption)
                                                            .foregroundStyle(.secondary)
                                                            .lineLimit(1)
                                                    }
                                                }
                                                Spacer()
                                            }
                                            .padding(.vertical, SSSpacing.md)
                                            .padding(.horizontal, SSSpacing.lg)
                                        }
                                        .buttonStyle(.plain)

                                        if item != searchResults.last {
                                            Divider().padding(.leading, 44)
                                        }
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                                        .fill(SSColor.backgroundCard)
                                )
                            }

                            if isSearching {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .controlSize(.small)
                                    Spacer()
                                }
                                .padding(.vertical, SSSpacing.md)
                            }
                        }
                    }

                    // MARK: - Map Preview
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: effectiveCoord,
                        latitudinalMeters: 2000,
                        longitudinalMeters: 2000
                    ))) {
                        Marker(effectivePlaceName, coordinate: effectiveCoord)
                            .tint(SSColor.meetup)
                    }
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: SSRadius.medium))
                    .allowsHitTesting(false)
                    .id(effectiveCoord.latitude + effectiveCoord.longitude) // force refresh on place change

                    // MARK: - Save Button
                    Button {
                        Task { await saveMeetup() }
                    } label: {
                        Text(L10n.meetupSave)
                            .font(SSFont.bodySemibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, SSSpacing.lg)
                            .background(
                                RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                                    .fill(canSave ? SSColor.meetup : SSColor.meetup.opacity(SSOpacity.disabled))
                            )
                    }
                    .disabled(!canSave)
                }
                .padding(.horizontal, SSSpacing.xl)
                .padding(.top, SSSpacing.xl)
                .padding(.bottom, SSSpacing.xxl)
            }
            .background {
                SSColor.backgroundPrimary.ignoresSafeArea()
            }
            .navigationTitle(L10n.meetupEdit)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
        }
    }

    // MARK: - Search

    private func searchPlaces() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.resultTypes = .pointOfInterest

        isSearching = true

        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            isSearching = false
            searchResults = Array((response?.mapItems ?? []).prefix(5))
        }
    }

    // MARK: - Save

    private func saveMeetup() async {
        let success = await viewModel.updateMeetup(
            title: title.trimmingCharacters(in: .whitespaces),
            meetupTime: meetupTime,
            placeName: effectivePlaceName,
            placeAddress: effectivePlaceAddress,
            latitude: effectiveCoord.latitude,
            longitude: effectiveCoord.longitude
        )

        if success {
            HapticEngine.shared.success()
            dismiss()
        }
    }
}
