import Foundation
import Testing
@testable import CycleSense

@Suite struct WidgetSnapshotTests {
    @Test func roundTripsThroughJSON() throws {
        let snapshot = WidgetSnapshot(
            cycleDay: 12,
            phase: "Follicular",
            nextPeriodStart: Date(timeIntervalSince1970: 1_790_000_000),
            fertileStart: Date(timeIntervalSince1970: 1_789_000_000),
            fertileEnd: Date(timeIntervalSince1970: 1_789_500_000),
            generatedAt: Date(timeIntervalSince1970: 1_788_000_000)
        )
        let defaults = UserDefaults(suiteName: "test-widget-snapshot")!
        defaults.removeObject(forKey: WidgetSnapshot.defaultsKey)
        snapshot.write(to: defaults)
        let loaded = WidgetSnapshot.read(from: defaults)
        #expect(loaded == snapshot)
    }

    @Test func missingDataReadsAsNil() {
        let defaults = UserDefaults(suiteName: "test-widget-snapshot-empty")!
        defaults.removeObject(forKey: WidgetSnapshot.defaultsKey)
        #expect(WidgetSnapshot.read(from: defaults) == nil)
    }
}
