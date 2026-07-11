import WidgetKit

/// Asks WidgetKit to rebuild the home-/lock-screen widget timelines from the
/// shared App-Group SwiftData store.
///
/// The widgets are only ever visible once the app leaves the foreground, and
/// nothing in the app previously called `WidgetCenter` at all — so after a user
/// added / edited / pinned / deleted a CountdownEvent, the widgets kept showing
/// stale data until iOS happened to refresh them (up to an hour later). Reloading
/// when the app backgrounds catches every mutation without having to instrument
/// each individual write site.
enum WidgetReloader {
    static func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
