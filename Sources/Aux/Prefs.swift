import Foundation

/// User preferences. Devices are *included* in the hotkey cycle by default —
/// a fresh install works immediately — and exclusions are stored by device UID
/// so they survive replugs and restarts.
final class Prefs: ObservableObject {
    static let shared = Prefs()

    private enum Keys {
        static let excludedOutputUIDs = "excludedOutputUIDs"
        static let excludedInputUIDs = "excludedInputUIDs"
        static let hasLaunchedBefore = "hasLaunchedBefore"
    }

    @Published var excludedOutputUIDs: Set<String> {
        didSet { UserDefaults.standard.set(Array(excludedOutputUIDs), forKey: Keys.excludedOutputUIDs) }
    }

    @Published var excludedInputUIDs: Set<String> {
        didSet { UserDefaults.standard.set(Array(excludedInputUIDs), forKey: Keys.excludedInputUIDs) }
    }

    private init() {
        excludedOutputUIDs = Set(UserDefaults.standard.stringArray(forKey: Keys.excludedOutputUIDs) ?? [])
        excludedInputUIDs = Set(UserDefaults.standard.stringArray(forKey: Keys.excludedInputUIDs) ?? [])
    }

    /// True exactly once, on the very first launch.
    func consumeFirstLaunch() -> Bool {
        guard !UserDefaults.standard.bool(forKey: Keys.hasLaunchedBefore) else { return false }
        UserDefaults.standard.set(true, forKey: Keys.hasLaunchedBefore)
        return true
    }
}
