import SwiftUI
import SwiftData

struct LaunchScreenView: View {
    var body: some View {
        SplashScreenView()
    }
}

#Preview {
    LaunchScreenView()
        .modelContainer(for: [CountdownEvent.self, UserSettings.self, DeadlineRecord.self], inMemory: true)
}
