import SwiftUI
import MapKit
import CoreLocation

struct MeetupDetailView: View {
    let meetup: MeetupSession
    @Bindable var viewModel: TeamProjectViewModel
    @State private var cameraPosition: MapCameraPosition = .automatic

    private let locationService = MeetupLocationService.shared

    private var meetupCoord: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: meetup.placeLatitude, longitude: meetup.placeLongitude)
    }

    private var timeUntilMeetup: String {
        let interval = meetup.meetupTime.timeIntervalSince(Date())
        if interval <= 0 { return L10n.meetupTimeArrived }
        let minutes = Int(interval) / 60
        if minutes < 60 { return L10n.meetupTimeMinutes(minutes) }
        let hours = minutes / 60
        let remainMin = minutes % 60
        if remainMin == 0 { return L10n.meetupTimeHours(hours) }
        return L10n.meetupTimeHoursMin(hours, remainMin)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: SSSpacing.xl) {
                // Map
                mapSection

                // Location sharing toggle + my ETA (only if joined)
                if viewModel.isInMeetup {
                    locationSharingToggle

                    // My ETA card (instant, from local calculation)
                    if locationService.isTracking {
                        myETACard
                    }
                }

                // Meetup info card
                infoCard

                // Member ETAs
                memberETAList
            }
            .padding(.horizontal, SSSpacing.xl)
            .padding(.top, SSSpacing.md)
            .padding(.bottom, SSSpacing.xxxl)
        }
        .background { SSColor.backgroundPrimary.ignoresSafeArea() }
        .navigationTitle(meetup.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if meetup.createdBy == viewModel.currentUid {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showingEditMeetup = true
                    } label: {
                        Image(systemName: "pencil.circle")
                            .foregroundStyle(SSColor.meetup)
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showingEditMeetup) {
            if let activeMeetup = viewModel.currentProject?.activeMeetup {
                EditMeetupSheet(meetup: activeMeetup, viewModel: viewModel)
            }
        }
        .onAppear {
            cameraPosition = .region(MKCoordinateRegion(
                center: meetupCoord,
                latitudinalMeters: 2000,
                longitudinalMeters: 2000
            ))
            startTrackingIfJoined()
        }
        .onDisappear {
            locationService.stopTracking()
        }
    }

    // MARK: - Location Sharing Toggle

    private var locationSharingToggle: some View {
        HStack(spacing: SSSpacing.md) {
            Image(systemName: locationService.isSharingLocation ? "location.fill" : "location.slash")
                .font(.title3)
                .foregroundStyle(locationService.isSharingLocation ? SSColor.meetup : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.meetupShareLocation)
                    .font(SSFont.bodyMedium)
                Text(L10n.meetupShareLocationDesc)
                    .font(SSFont.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Bindable(locationService).isSharingLocation)
                .labelsHidden()
        }
        .padding(SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
    }

    // MARK: - My ETA Card

    private var myETACard: some View {
        VStack(spacing: SSSpacing.lg) {
            HStack(spacing: SSSpacing.md) {
                Image(systemName: "location.fill")
                    .font(.title3)
                    .foregroundStyle(SSColor.meetup)
                Text(L10n.meetupMyETA)
                    .font(SSFont.bodyMedium)
                Spacer()
            }

            HStack(spacing: 0) {
                myETAColumn(icon: "car.fill", seconds: locationService.myDrivingETA, color: .blue)
                Spacer()
                myETAColumn(icon: "bus.fill", seconds: locationService.myTransitETA, color: .green)
                Spacer()
                myETAColumn(icon: "figure.walk", seconds: locationService.myWalkingETA, color: .orange)
            }
        }
        .padding(SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
    }

    private func myETAColumn(icon: String, seconds: Int?, color: Color) -> some View {
        VStack(spacing: SSSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(seconds != nil ? color : .secondary)
            if let seconds {
                Text(MeetupLocationService.formatETA(seconds))
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Map

    private var mapSection: some View {
        Map(position: $cameraPosition) {
            // Meetup place pin
            Marker(meetup.placeName, systemImage: "mappin.circle.fill", coordinate: meetupCoord)
                .tint(SSColor.meetup)

            // Approximate member areas (only for members sharing location)
            ForEach(viewModel.meetupLocations.filter(\.sharingLocation)) { member in
                let coord = CLLocationCoordinate2D(
                    latitude: member.approxLatitude,
                    longitude: member.approxLongitude
                )

                // Blurred zone circle
                MapCircle(center: coord, radius: 500)
                    .foregroundStyle(SSColor.brand.opacity(SSOpacity.tagBackground))

                // Emoji annotation at approximate center
                Annotation(member.displayName, coordinate: coord) {
                    Text(member.avatarEmoji)
                        .font(.system(size: 20))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.white.opacity(0.85))
                                .shadow(radius: 2)
                        )
                }
            }
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: SSRadius.large))
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(spacing: SSSpacing.lg) {
            // Place name + address
            HStack(spacing: SSSpacing.md) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title2)
                    .foregroundStyle(SSColor.meetup)
                VStack(alignment: .leading, spacing: 2) {
                    Text(meetup.placeName)
                        .font(SSFont.bodyMedium)
                    if !meetup.placeAddress.isEmpty {
                        Text(meetup.placeAddress)
                            .font(SSFont.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
            }

            Divider()

            // Time
            HStack(spacing: SSSpacing.md) {
                Image(systemName: "clock.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(meetup.meetupTime, style: .date)
                        .font(SSFont.bodyMedium)
                    +
                    Text("  ")
                    +
                    Text(meetup.meetupTime, style: .time)
                        .font(SSFont.bodyMedium)

                    Text(timeUntilMeetup)
                        .font(SSFont.caption)
                        .foregroundStyle(meetup.meetupTime > Date() ? .orange : .green)
                }
                Spacer()
            }

            Divider()

            // Attendees
            HStack(spacing: SSSpacing.md) {
                Image(systemName: "person.2.fill")
                    .font(.title3)
                    .foregroundStyle(SSColor.brand)
                Text(L10n.meetupAttendees(meetup.attendeeIds.count))
                    .font(SSFont.bodyMedium)
                Spacer()

                // Join button if not joined
                if !viewModel.isInMeetup {
                    Button {
                        Task {
                            await viewModel.joinMeetup()
                            startTrackingIfJoined()
                        }
                        HapticEngine.shared.success()
                    } label: {
                        Text(L10n.meetupJoin)
                            .font(SSFont.chipLabel)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(SSColor.meetup))
                    }
                }
            }

            // Navigate button
            Button {
                openInMaps()
            } label: {
                HStack(spacing: SSSpacing.md) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    Text(L10n.meetupNavigate)
                }
                .font(SSFont.bodySemibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SSSpacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                        .fill(SSColor.meetup)
                )
            }
        }
        .padding(SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
    }

    // MARK: - Member ETA List

    private var memberETAList: some View {
        VStack(alignment: .leading, spacing: SSSpacing.lg) {
            Text(L10n.meetupMemberETAs)
                .font(SSFont.sectionHeader)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if viewModel.meetupLocations.isEmpty {
                VStack(spacing: SSSpacing.md) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text(L10n.meetupNoLocations)
                        .font(SSFont.secondary)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, SSSpacing.xxxl)
            } else {
                // ETA legend
                HStack(spacing: SSSpacing.xl) {
                    etaLegendItem(icon: "car.fill", label: L10n.meetupEtaDriving)
                    etaLegendItem(icon: "bus.fill", label: L10n.meetupEtaTransit)
                    etaLegendItem(icon: "figure.walk", label: L10n.meetupEtaWalking)
                    Spacer()
                }
                .padding(.bottom, SSSpacing.sm)

                ForEach(viewModel.meetupLocations.sorted(by: {
                    ($0.etaDrivingSeconds ?? .max) < ($1.etaDrivingSeconds ?? .max)
                })) { member in
                    memberETARow(member)
                }
            }
        }
        .padding(SSSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.card, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
    }

    private func etaLegendItem(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(label)
                .font(.system(size: 11))
        }
        .foregroundStyle(.secondary)
    }

    private func memberETARow(_ member: MeetupMemberLocation) -> some View {
        HStack(spacing: SSSpacing.lg) {
            Text(member.avatarEmoji)
                .font(.system(size: 24))
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color(.tertiarySystemFill)))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(member.displayName)
                        .font(SSFont.bodyMedium)

                    if !member.sharingLocation {
                        Image(systemName: "location.slash")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

                // 3 ETA chips
                HStack(spacing: SSSpacing.md) {
                    etaChip(icon: "car.fill", seconds: member.etaDrivingSeconds, color: .blue)
                    etaChip(icon: "bus.fill", seconds: member.etaTransitSeconds, color: .green)
                    etaChip(icon: "figure.walk", seconds: member.etaWalkingSeconds, color: .orange)
                }
            }

            Spacer()

            // Freshness indicator
            let age = Date().timeIntervalSince(member.updatedAt)
            if age < 60 {
                Circle().fill(.green).frame(width: 8, height: 8)
            } else if age < 300 {
                Circle().fill(.yellow).frame(width: 8, height: 8)
            } else {
                Circle().fill(.gray).frame(width: 8, height: 8)
            }
        }
    }

    private func etaChip(icon: String, seconds: Int?, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
            if let seconds {
                Text(MeetupLocationService.formatETA(seconds))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            } else {
                Text("--")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
        }
        .foregroundStyle(seconds != nil ? color : .secondary)
    }

    // MARK: - Actions

    private func startTrackingIfJoined() {
        guard viewModel.isInMeetup else { return }
        let service = MeetupLocationService.shared
        if !service.hasPermission {
            service.requestPermission()
        }
        if service.hasPermission, let projectId = viewModel.currentProject?.id {
            service.startTracking(
                projectId: projectId,
                destination: meetupCoord,
                meetupTime: meetup.meetupTime,
                meetupTitle: meetup.title,
                placeName: meetup.placeName
            )
        }
    }

    private func openInMaps() {
        let placemark = MKPlacemark(coordinate: meetupCoord)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = meetup.placeName
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}
