import Foundation
import SwiftData

/// Process-wide reference to the active SwiftData `ModelContainer`.
///
/// ────────────────────────────────────────────────────────────────────────
/// Why this exists — read this before touching SwiftData anywhere
/// ────────────────────────────────────────────────────────────────────────
///
/// **Multiple `ModelContainer` instances opening the same store URL in the
/// same process is undefined behavior in CoreData/SwiftData and CAN
/// CORRUPT THE STORE.** Two containers fight over SQLite locks and metadata
/// writes; the result is a store that's either unreadable on next launch
/// or has been silently mutated in ways neither container expected.
///
/// We hit this in v1.0 — `DeadlineBackgroundChecker` and several
/// `AppIntent`s called `SharedModelContainer.create()` to make their own
/// container with a *different schema* than the main app's, pointing at the
/// same App Group store URL. iOS triggered the background task or routed
/// an intent to the main app process while the main `ModelContainer` was
/// already live → metadata corruption → next launch the persistent store
/// failed to load → silent in-memory fallback in `StudySyncApp` →
/// user reported "all my data is gone".
///
/// ────────────────────────────────────────────────────────────────────────
/// The rule
/// ────────────────────────────────────────────────────────────────────────
///
///   • In the **main app process**: every SwiftData consumer reads
///     `AppContainer.shared.container` (set in `StudySyncApp.init`). NEVER
///     call `ModelContainer(for:configurations:)` yourself for the main
///     store. Use `try AppContainer.shared.requireContainer()` if you need
///     to fail loudly when it's missing.
///
///   • In a **separate process** (Widget extension, Messages extension):
///     it's OK to construct your own container via
///     `SharedModelContainer.create()`. Different processes have their own
///     CoreData state. **Schema must still match the main app's** —
///     otherwise cross-process writes corrupt metadata. (See the comment
///     in SharedModelContainer.swift for the schema-unification TODO.)
///
@MainActor
final class AppContainer {
    static let shared = AppContainer()

    /// nil only during the brief window before `StudySyncApp.init` finishes.
    /// UI hasn't appeared yet at that point so SwiftData consumers can't
    /// reach this. After init, this is the container the entire main app
    /// process must use.
    private(set) var container: ModelContainer?

    private init() {}

    /// Called from `StudySyncApp.init` once the main `ModelContainer` is
    /// constructed. There must be exactly one call per process lifetime.
    func register(_ container: ModelContainer) {
        if self.container != nil {
            // Misuse — two registrations would mean two containers on the
            // same store URL, the exact bug this whole file is trying to
            // prevent. Surface it loudly in DEBUG; in release we keep the
            // first one and ignore the second to avoid handing out a
            // container some callers haven't seen yet.
            assertionFailure(
                "AppContainer.register called twice — duplicate ModelContainer "
                + "in the same process risks store corruption."
            )
            return
        }
        self.container = container
    }

    /// Throwing accessor for callers that need to abort cleanly when the
    /// container isn't set (background task that woke before app init
    /// completed, etc.). Prefer this over force-unwrap.
    func requireContainer() throws -> ModelContainer {
        guard let container else {
            throw AppContainerError.notInitialized
        }
        return container
    }
}

enum AppContainerError: Error, LocalizedError {
    case notInitialized

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "AppContainer was accessed before StudySyncApp.init completed."
        }
    }
}
