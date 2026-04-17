import Foundation
import CoreLocation
import MapKit
import ActivityKit

/// Manages real-time location tracking for meetup sessions.
/// Uploads blurred position + 3 ETAs (driving / transit / walking) to Firestore.
/// Starts a Live Activity with Dynamic Island showing countdown + ETAs.
@Observable
final class MeetupLocationService: NSObject {
    static let shared = MeetupLocationService()

    // Published state
    var currentLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var isTracking = false
    var isSharingLocation = true   // user toggle: show approximate position on map
    var myDrivingETA: Int?         // latest driving ETA (local, instant)
    var myTransitETA: Int?         // latest transit ETA (local, instant)
    var myWalkingETA: Int?         // latest walking ETA (local, instant)

    // Private
    private let locationManager = CLLocationManager()
    private var projectId: String?
    private var destination: CLLocationCoordinate2D?
    private var meetupTime: Date?
    private var meetupTitle: String?
    private var placeName: String?
    private var uploadTimer: Timer?
    private let firestore = FirestoreService.shared

    /// Update the tracking destination (e.g. when meetup location is edited).
    func updateDestination(_ coord: CLLocationCoordinate2D) {
        destination = coord
        if isTracking {
            uploadLocation()
        }
    }

    // Live Activity
    private var meetupActivity: Activity<MeetupActivityAttributes>?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 50  // Update every 50m
    }

    // MARK: - Permission

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    var hasPermission: Bool {
        [.authorizedWhenInUse, .authorizedAlways].contains(authorizationStatus)
    }

    // MARK: - Tracking

    func startTracking(
        projectId: String,
        destination: CLLocationCoordinate2D,
        meetupTime: Date,
        meetupTitle: String,
        placeName: String
    ) {
        self.projectId = projectId
        self.destination = destination
        self.meetupTime = meetupTime
        self.meetupTitle = meetupTitle
        self.placeName = placeName
        isTracking = true

        locationManager.startUpdatingLocation()

        // Periodic upload every 30s
        uploadTimer?.invalidate()
        uploadTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.uploadLocation()
        }
        RunLoop.current.add(uploadTimer!, forMode: .common)

        // Immediate first upload after a brief delay for location fix
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.uploadLocation()
        }
    }

    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
        uploadTimer?.invalidate()
        uploadTimer = nil
        myDrivingETA = nil
        myTransitETA = nil
        myWalkingETA = nil
        projectId = nil
        destination = nil

        // End Live Activity
        endLiveActivity()
        meetupTime = nil
        meetupTitle = nil
        placeName = nil
    }

    // MARK: - Coordinate Blurring

    /// Blur coordinates to ~500m precision grid.
    /// 1° latitude ≈ 111 km → 0.005° ≈ 555 m
    static func blurCoordinate(_ coord: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let gridSize = 0.005
        let blurredLat = (coord.latitude / gridSize).rounded() * gridSize
        let blurredLng = (coord.longitude / gridSize).rounded() * gridSize
        return CLLocationCoordinate2D(latitude: blurredLat, longitude: blurredLng)
    }

    // MARK: - Upload

    private func uploadLocation() {
        guard let projectId,
              let location = currentLocation,
              let profile = AuthService.shared.userProfile else { return }

        let blurred = Self.blurCoordinate(location.coordinate)

        let memberLocation = MeetupMemberLocation(
            id: profile.id,
            displayName: profile.displayName,
            avatarEmoji: profile.avatarEmoji,
            approxLatitude: blurred.latitude,
            approxLongitude: blurred.longitude,
            sharingLocation: isSharingLocation,
            updatedAt: Date()
        )

        Task {
            // Upload basic info first
            await firestore.updateMeetupLocation(projectId: projectId, location: memberLocation)

            // Calculate all 3 ETAs in parallel, then update
            if let dest = destination {
                let etas = await calculateAllETAs(from: location.coordinate, to: dest)
                var updated = memberLocation
                updated.etaDrivingSeconds = etas.driving
                updated.etaTransitSeconds = etas.transit
                updated.etaWalkingSeconds = etas.walking
                await firestore.updateMeetupLocation(projectId: projectId, location: updated)

                // Store locally for instant display
                await MainActor.run {
                    self.myDrivingETA = etas.driving
                    self.myTransitETA = etas.transit
                    self.myWalkingETA = etas.walking
                }

                // Update Live Activity with fresh ETAs
                updateLiveActivity(etas: etas)
            }
        }
    }

    // MARK: - Live Activity

    /// Start Live Activity independently from location tracking.
    /// Called by ViewModel on create / join / app launch.
    func startLiveActivity(meetupTime: Date, meetupTitle: String, placeName: String, destLatitude: Double, destLongitude: Double) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Already showing this meetup — skip
        if meetupActivity != nil { return }

        // Store for later ETA updates
        self.meetupTime = meetupTime
        self.meetupTitle = meetupTitle
        self.placeName = placeName

        let attributes = MeetupActivityAttributes(
            meetupTitle: meetupTitle,
            placeName: placeName,
            meetupTime: meetupTime,
            destLatitude: destLatitude,
            destLongitude: destLongitude
        )

        let initialState = MeetupActivityAttributes.ContentState(
            etaDrivingSeconds: nil,
            etaTransitSeconds: nil,
            etaWalkingSeconds: nil,
            shouldLeaveNow: false,
            userLatitude: nil,
            userLongitude: nil
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: nil),
                pushType: nil
            )
            meetupActivity = activity
        } catch {
            debugPrint("[MeetupLocation] Failed to start Live Activity: \(error)")
        }
    }

    private func updateLiveActivity(etas: AllETAs) {
        guard let activity = meetupActivity, let meetupTime else { return }

        let remaining = Int(meetupTime.timeIntervalSinceNow)

        // "Should leave now" = remaining ≤ fastest ETA + 5 min buffer
        let fastestETA = [etas.driving, etas.transit, etas.walking]
            .compactMap { $0 }
            .min() ?? Int.max
        let shouldLeave = remaining <= fastestETA + 300 && remaining > 0

        // Blur user coordinates for map display on lock screen
        let userCoord: CLLocationCoordinate2D? = currentLocation.map {
            Self.blurCoordinate($0.coordinate)
        }

        let state = MeetupActivityAttributes.ContentState(
            etaDrivingSeconds: etas.driving,
            etaTransitSeconds: etas.transit,
            etaWalkingSeconds: etas.walking,
            shouldLeaveNow: shouldLeave,
            userLatitude: userCoord?.latitude,
            userLongitude: userCoord?.longitude
        )

        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    /// End Live Activity. Public so ViewModel can call on meetup end.
    func endLiveActivity() {
        guard let activity = meetupActivity else { return }

        let finalState = MeetupActivityAttributes.ContentState(
            etaDrivingSeconds: nil,
            etaTransitSeconds: nil,
            etaWalkingSeconds: nil,
            shouldLeaveNow: false,
            userLatitude: nil,
            userLongitude: nil
        )

        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .after(.now + 30)
            )
        }
        meetupActivity = nil
    }

    // MARK: - ETA Calculation

    struct AllETAs {
        let driving: Int?
        let transit: Int?
        let walking: Int?
    }

    /// Calculate driving, transit, and walking ETAs in parallel.
    func calculateAllETAs(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> AllETAs {
        async let drivingETA = calculateSingleETA(from: from, to: to, transport: .automobile)
        async let transitETA = calculateSingleETA(from: from, to: to, transport: .transit)
        async let walkingETA = calculateSingleETA(from: from, to: to, transport: .walking)

        return await AllETAs(
            driving: drivingETA,
            transit: transitETA,
            walking: walkingETA
        )
    }

    private func calculateSingleETA(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        transport: MKDirectionsTransportType
    ) async -> Int? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = transport

        let directions = MKDirections(request: request)
        do {
            let response = try await directions.calculate()
            if let route = response.routes.first {
                return Int(route.expectedTravelTime)
            }
        } catch {
            // Transit / walking may not be available in all areas
            debugPrint("[MeetupLocation] ETA failed for \(transport): \(error.localizedDescription)")
        }
        return nil
    }

    // MARK: - Static Helpers

    /// Calculate straight-line distance between two coordinates.
    static func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return loc1.distance(from: loc2)
    }

    /// Format distance for display.
    static func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters)) m"
    }

    /// Format ETA seconds for display.
    static func formatETA(_ seconds: Int) -> String {
        if seconds < 60 {
            return "<1 min"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainingMin = minutes % 60
        if remainingMin == 0 {
            return "\(hours)h"
        }
        return "\(hours)h\(remainingMin)m"
    }
}

// MARK: - CLLocationManagerDelegate

extension MeetupLocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
}
