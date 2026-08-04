import Testing
@testable import CycleSense

@Suite struct SmokeTests {
    @Test func targetLinks() {
        #expect(CyclePredictor.defaultCycleLength == 28)
    }
}
