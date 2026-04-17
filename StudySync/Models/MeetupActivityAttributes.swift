import ActivityKit
import Foundation

struct MeetupActivityAttributes: ActivityAttributes {
    let meetupTitle: String
    let placeName: String
    let meetupTime: Date
    let destLatitude: Double
    let destLongitude: Double

    struct ContentState: Codable, Hashable {
        let etaDrivingSeconds: Int?
        let etaTransitSeconds: Int?
        let etaWalkingSeconds: Int?
        let shouldLeaveNow: Bool   // remaining ≤ fastest ETA + 5 min
        let userLatitude: Double?
        let userLongitude: Double?
    }
}
