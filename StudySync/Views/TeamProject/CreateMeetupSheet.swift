import SwiftUI
import MapKit

struct CreateMeetupSheet: View {
    @Bindable var viewModel: TeamProjectViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var meetupTime = Date().addingTimeInterval(3600)
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedPlace: MKMapItem?
    @State private var isSearching = false

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && selectedPlace != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SSSpacing.xxl) {
                    // Hero
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(SSColor.meetup)
                        .padding(.top, SSSpacing.xxxl)

                    Text(L10n.meetupCreateDesc)
                        .font(SSFont.secondary)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    // Title
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

                    // Time
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

                    // Place search
                    VStack(alignment: .leading, spacing: SSSpacing.sm) {
                        Text(L10n.meetupPlaceLabel)
                            .font(SSFont.caption)
                            .foregroundStyle(.secondary)

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
                        }
                        .padding(SSSpacing.xl)
                        .background(
                            RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                                .fill(SSColor.backgroundCard)
                        )

                        // Selected place
                        if let place = selectedPlace {
                            HStack(spacing: SSSpacing.md) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(SSColor.meetup)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name ?? "")
                                        .font(SSFont.bodyMedium)
                                    if let address = place.placemark.formattedAddress {
                                        Text(address)
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
                        }

                        // Search results
                        if !searchResults.isEmpty && selectedPlace == nil {
                            VStack(spacing: 0) {
                                ForEach(searchResults, id: \.self) { item in
                                    Button {
                                        selectedPlace = item
                                        searchText = item.name ?? ""
                                        searchResults = []
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

                    // Map preview
                    if let place = selectedPlace {
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: place.placemark.coordinate,
                            latitudinalMeters: 2000,
                            longitudinalMeters: 2000
                        ))) {
                            Marker(place.name ?? "", coordinate: place.placemark.coordinate)
                                .tint(SSColor.meetup)
                        }
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: SSRadius.medium))
                        .allowsHitTesting(false)
                    }

                    // Create button
                    Button {
                        Task { await createMeetup() }
                    } label: {
                        Text(L10n.meetupCreate)
                            .font(SSFont.bodySemibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, SSSpacing.lg)
                            .background(
                                RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                                    .fill(canCreate ? SSColor.meetup : SSColor.meetup.opacity(SSOpacity.disabled))
                            )
                    }
                    .disabled(!canCreate)
                }
                .padding(.horizontal, SSSpacing.xl)
                .padding(.bottom, SSSpacing.xxl)
            }
            .background {
                SSColor.backgroundPrimary.ignoresSafeArea()
            }
            .navigationTitle(L10n.meetupCreate)
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
        selectedPlace = nil

        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            isSearching = false
            searchResults = Array((response?.mapItems ?? []).prefix(5))
        }
    }

    // MARK: - Create

    private func createMeetup() async {
        guard let place = selectedPlace else { return }
        let coord = place.placemark.coordinate
        let address = place.placemark.formattedAddress ?? ""

        let success = await viewModel.createMeetup(
            title: title.trimmingCharacters(in: .whitespaces),
            meetupTime: meetupTime,
            placeName: place.name ?? title,
            placeAddress: address,
            latitude: coord.latitude,
            longitude: coord.longitude
        )

        if success {
            HapticEngine.shared.success()
            dismiss()
        }
    }
}

// MARK: - Placemark Address Helper

extension CLPlacemark {
    var formattedAddress: String? {
        let parts = [thoroughfare, subLocality, locality, administrativeArea].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
