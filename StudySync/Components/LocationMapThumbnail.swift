import SwiftUI
import MapKit

/// Compact map thumbnail that geocodes a location string and shows
/// a static preview with a red marker. Tapping opens Apple Maps.
struct LocationMapThumbnail: View {
    let location: String
    var onOpenInMaps: (() -> Void)?

    @State private var coordinate: CLLocationCoordinate2D?
    @State private var isGeocoding = true
    @State private var weather: WeatherService.Current?

    var body: some View {
        Button {
            onOpenInMaps?()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Map preview
                mapPreview
                    .frame(height: 140)
                    .clipped()
                    .overlay(alignment: .topTrailing) {
                        if let weather = weather {
                            weatherChip(weather)
                                .padding(8)
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                    }
                    .allowsHitTesting(false)

                // Location label row
                HStack(spacing: 10) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(.red)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.calLocation)
                            .font(SSFont.caption)
                            .foregroundStyle(.secondary)
                        Text(location)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right.square")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }
                .padding(SSSpacing.lg)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .task { await geocode() }
    }

    // MARK: - Map Preview

    @ViewBuilder
    private var mapPreview: some View {
        if let coord = coordinate {
            Map(
                initialPosition: .region(
                    MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
                    )
                ),
                interactionModes: []
            ) {
                Marker(location, coordinate: coord)
                    .tint(.red)
            }
            .mapStyle(.standard(pointsOfInterest: .all))
        } else if isGeocoding {
            ZStack {
                Color(.systemGray5)
                ProgressView()
            }
        } else {
            // Geocoding failed — show placeholder with icon
            ZStack {
                Color(.systemGray5)
                VStack(spacing: 6) {
                    Image(systemName: "map")
                        .font(.title2)
                    Text(L10n.calLocation)
                        .font(SSFont.caption)
                }
                .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Weather Chip

    @ViewBuilder
    private func weatherChip(_ w: WeatherService.Current) -> some View {
        HStack(spacing: 5) {
            Image(systemName: w.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .symbolRenderingMode(.multicolor)
            Text(w.temperatureLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule().stroke(Color.white.opacity(0.35), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
    }

    // MARK: - Geocode

    private func geocode() async {
        do {
            let placemarks = try await CLGeocoder().geocodeAddressString(location)
            if let coord = placemarks.first?.location?.coordinate {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        coordinate = coord
                    }
                    isGeocoding = false
                }
                await fetchWeather(for: coord)
                return
            }
        } catch {}
        await MainActor.run { isGeocoding = false }
    }

    private func fetchWeather(for coord: CLLocationCoordinate2D) async {
        let result = await WeatherService.shared.current(for: coord)
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.35)) {
                weather = result
            }
        }
    }
}
