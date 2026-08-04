import Foundation

/// Cycle state the widget renders. The app writes it to the App Group after
/// every data refresh; the widget only ever reads it (widget extensions
/// cannot query HealthKit).
struct WidgetSnapshot: Codable, Equatable {
    static let appGroupID = "group.com.example.CycleSense"
    static let defaultsKey = "widgetSnapshot"

    var cycleDay: Int?
    var phase: String?
    var nextPeriodStart: Date?
    var fertileStart: Date?
    var fertileEnd: Date?
    var generatedAt: Date

    static var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    func write(to defaults: UserDefaults?) {
        guard let defaults, let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }

    static func read(from defaults: UserDefaults?) -> WidgetSnapshot? {
        guard let defaults, let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
