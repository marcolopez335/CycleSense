# CycleSense Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add predictor unit tests, expanded logging (weight, mood, sex, cravings, BBT, ovulation tests), period/fertile reminders, and a Home Screen widget to CycleSense.

**Architecture:** Four sequential sub-projects, each shippable alone. All new health data flows through the existing pattern: `Models` (HealthKit-free types) → `HealthKitManager` (async read/write) → `CycleStore` (observable state) → views. Notifications and the widget consume `Prediction` output; the widget reads an App Group snapshot because widget extensions cannot query HealthKit.

**Tech Stack:** SwiftUI, HealthKit (incl. `HKStateOfMind`), Swift Testing, UserNotifications, WidgetKit. iOS 17.0 target, Xcode 26.3.

**Build/test commands** (headless, run from repo root):

```bash
# Build app for simulator
xcodebuild -project CycleSense.xcodeproj -scheme CycleSense -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/cs-dd build

# Run unit tests
xcodebuild -project CycleSense.xcodeproj -scheme CycleSense -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/cs-dd test
```

Simulator verification workflow: build, then install/launch `CycleSense.app` from the derived-data products dir on the booted iPhone 17 Pro simulator (UDID `386E2C64-0E1E-4C7E-AFBF-8DCDFCA4A5AB`), screenshot, drive taps.

**pbxproj conventions:** the project uses `objectVersion = 77` with `PBXFileSystemSynchronizedRootGroup` (folder-synchronized) groups — files on disk inside a synchronized folder are automatically target members; no per-file build entries needed. Existing object IDs use the `AB00000000000000000000XX` pattern; new objects continue it from `…10` up.

---

## Sub-project 1: CyclePredictor unit tests

### Task 1: Add unit-test target to the Xcode project

**Files:**
- Create: `CycleSenseTests/` (directory, will hold test sources)
- Modify: `CycleSense.xcodeproj/project.pbxproj`

- [ ] **Step 1.1: Create the test directory with a placeholder test**

Create `CycleSenseTests/CyclePredictorTests.swift`:

```swift
import Testing
@testable import CycleSense

@Suite struct SmokeTests {
    @Test func targetLinks() {
        #expect(CyclePredictor.defaultCycleLength == 28)
    }
}
```

- [ ] **Step 1.2: Register the synchronized group in project.pbxproj**

In `CycleSense.xcodeproj/project.pbxproj`, insert into the `PBXFileSystemSynchronizedRootGroup` section (after the closing `};` of `AB0000000000000000000001 /* CycleSense */`):

```
		AB0000000000000000000010 /* CycleSenseTests */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			explicitFileTypes = {
			};
			explicitFolders = (
			);
			path = CycleSenseTests;
			sourceTree = "<group>";
		};
```

- [ ] **Step 1.3: Add file reference for the test bundle product**

In the `PBXFileReference` section add:

```
		AB0000000000000000000011 /* CycleSenseTests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = CycleSenseTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
```

Add `AB0000000000000000000011 /* CycleSenseTests.xctest */,` to the `children` of `AB0000000000000000000003 /* Products */`, and `AB0000000000000000000010 /* CycleSenseTests */,` to the `children` of the main group `AB0000000000000000000002`.

- [ ] **Step 1.4: Add the test native target, build phases, dependency, configs**

Add to `PBXNativeTarget` section:

```
		AB0000000000000000000012 /* CycleSenseTests */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = AB0000000000000000000013 /* Build configuration list for PBXNativeTarget "CycleSenseTests" */;
			buildPhases = (
				AB0000000000000000000014 /* Sources */,
				AB0000000000000000000015 /* Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
				AB0000000000000000000016 /* PBXTargetDependency */,
			);
			fileSystemSynchronizedGroups = (
				AB0000000000000000000010 /* CycleSenseTests */,
			);
			name = CycleSenseTests;
			packageProductDependencies = (
			);
			productName = CycleSenseTests;
			productReference = AB0000000000000000000011 /* CycleSenseTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		};
```

New `PBXSourcesBuildPhase` + `PBXFrameworksBuildPhase` entries (same empty shape as the app's — add alongside existing ones in their sections):

```
		AB0000000000000000000014 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		AB0000000000000000000015 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
```

New sections (place after `PBXSourcesBuildPhase`):

```
/* Begin PBXTargetDependency section */
		AB0000000000000000000016 /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = AB0000000000000000000006 /* CycleSense */;
			targetProxy = AB0000000000000000000017 /* PBXContainerItemProxy */;
		};
/* End PBXTargetDependency section */

/* Begin PBXContainerItemProxy section */
		AB0000000000000000000017 /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = AB000000000000000000000A /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = AB0000000000000000000006;
			remoteInfo = CycleSense;
		};
/* End PBXContainerItemProxy section */
```

Add to `XCBuildConfiguration` section:

```
		AB0000000000000000000018 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.CycleSenseTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/CycleSense.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/CycleSense";
			};
			name = Debug;
		};
		AB0000000000000000000019 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.CycleSenseTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/CycleSense.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/CycleSense";
			};
			name = Release;
		};
```

Add to `XCConfigurationList` section:

```
		AB0000000000000000000013 /* Build configuration list for PBXNativeTarget "CycleSenseTests" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				AB0000000000000000000018 /* Debug */,
				AB0000000000000000000019 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
```

Finally: add `AB0000000000000000000012 /* CycleSenseTests */,` to the `targets` list of the `PBXProject` object, and to `TargetAttributes` add:

```
					AB0000000000000000000012 = {
						CreatedOnToolsVersion = 16.0;
						TestTargetID = AB0000000000000000000006;
					};
```

- [ ] **Step 1.5: Run the smoke test**

Run the test command from the header. Expected: `** TEST SUCCEEDED **` with 1 test passing.
If xcodebuild reports the scheme has no test action, create `CycleSense.xcodeproj/xcshareddata/xcschemes/CycleSense.xcscheme`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1600" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "AB0000000000000000000006" BuildableName = "CycleSense.app" BlueprintName = "CycleSense" ReferencedContainer = "container:CycleSense.xcodeproj"/>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference skipped = "NO">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "AB0000000000000000000012" BuildableName = "CycleSenseTests.xctest" BlueprintName = "CycleSenseTests" ReferencedContainer = "container:CycleSense.xcodeproj"/>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "AB0000000000000000000006" BuildableName = "CycleSense.app" BlueprintName = "CycleSense" ReferencedContainer = "container:CycleSense.xcodeproj"/>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES"/>
   <AnalyzeAction buildConfiguration = "Debug"/>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"/>
</Scheme>
```

Then rerun. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 1.6: Commit**

```bash
git add CycleSenseTests CycleSense.xcodeproj
git commit -m "test: add CycleSenseTests unit-test target"
```

### Task 2: Characterization tests for CyclePredictor

**Files:**
- Modify: `CycleSenseTests/CyclePredictorTests.swift` (replace placeholder entirely)

These are characterization tests: the implementation already exists and is believed correct, so every test is expected to PASS on first run. A failure means either the test's expected value is miscomputed (recheck by hand) or a real predictor bug (stop and report — do not silently change the implementation).

- [ ] **Step 2.1: Replace the placeholder with the full suite**

```swift
import Foundation
import Testing
@testable import CycleSense

/// Fixed UTC calendar so results don't depend on the machine's timezone.
private let utc: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal
}()

/// Builds a date at midnight UTC.
private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
    utc.date(from: DateComponents(year: y, month: m, day: d))!
}

/// N consecutive flow days starting at `start`.
private func flowRun(from start: Date, count: Int) -> [Date] {
    (0..<count).map { utc.date(byAdding: .day, value: $0, to: start)! }
}

@Suite struct CycleGroupingTests {
    @Test func emptyInputGivesNoCycles() {
        #expect(CyclePredictor.cycles(fromFlowDays: [], calendar: utc).isEmpty)
    }

    @Test func singleEpisodeMakesOneOpenCycle() {
        let cycles = CyclePredictor.cycles(fromFlowDays: flowRun(from: day(2026, 1, 1), count: 5), calendar: utc)
        #expect(cycles.count == 1)
        #expect(cycles[0].start == day(2026, 1, 1))
        #expect(cycles[0].periodLength == 5)
        #expect(cycles[0].cycleLength == nil)
    }

    @Test func oneMissedDayIsBridged() {
        // Days 1,2,4,5 — the gap on day 3 stays inside one episode.
        let days = [day(2026, 1, 1), day(2026, 1, 2), day(2026, 1, 4), day(2026, 1, 5)]
        let cycles = CyclePredictor.cycles(fromFlowDays: days, calendar: utc)
        #expect(cycles.count == 1)
        #expect(cycles[0].periodLength == 5)
    }

    @Test func twoDayGapSplitsEpisodes() {
        // Days 1,2 then 5,6 — two episodes; cycle length = 4 days.
        let days = [day(2026, 1, 1), day(2026, 1, 2), day(2026, 1, 5), day(2026, 1, 6)]
        let cycles = CyclePredictor.cycles(fromFlowDays: days, calendar: utc)
        #expect(cycles.count == 2)
        #expect(cycles[0].cycleLength == 4)
        #expect(cycles[1].cycleLength == nil)
    }

    @Test func duplicateAndUnsortedInputIsNormalized() {
        let days = [day(2026, 1, 2), day(2026, 1, 1), day(2026, 1, 2)]
        let cycles = CyclePredictor.cycles(fromFlowDays: days, calendar: utc)
        #expect(cycles.count == 1)
        #expect(cycles[0].start == day(2026, 1, 1))
        #expect(cycles[0].periodLength == 2)
    }
}

@Suite struct PredictionTests {
    /// Four regular 28-day cycles, 5-day periods, starting 2026-01-01.
    private var regularCycles: [Cycle] {
        var flow: [Date] = []
        for offset in [0, 28, 56, 84] {
            flow += flowRun(from: utc.date(byAdding: .day, value: offset, to: day(2026, 1, 1))!, count: 5)
        }
        return CyclePredictor.cycles(fromFlowDays: flow, calendar: utc)
    }

    @Test func noCyclesGivesNilPrediction() {
        #expect(CyclePredictor.prediction(from: [], today: day(2026, 8, 3), calendar: utc) == nil)
    }

    @Test func defaultsUsedWithSingleEpisode() {
        let cycles = CyclePredictor.cycles(fromFlowDays: flowRun(from: day(2026, 1, 1), count: 5), calendar: utc)
        let p = CyclePredictor.prediction(from: cycles, today: day(2026, 1, 10), calendar: utc)!
        #expect(p.averageCycleLength == 28)
        #expect(p.averagePeriodLength == 5)
        #expect(p.nextPeriodStart == day(2026, 1, 29))
        #expect(p.ovulationDate == day(2026, 1, 15))
        #expect(p.fertileWindow == DateInterval(start: day(2026, 1, 10), end: day(2026, 1, 16)))
    }

    @Test func regularHistoryPredictsNextPeriod() {
        // Last period start 2026-03-26 (offset 84); next = +28 = 2026-04-23.
        let p = CyclePredictor.prediction(from: regularCycles, today: day(2026, 3, 28), calendar: utc)!
        #expect(p.averageCycleLength == 28)
        #expect(p.averagePeriodLength == 5)
        #expect(p.nextPeriodStart == day(2026, 4, 23))
        #expect(p.ovulationDate == day(2026, 4, 9))
        #expect(p.fertileWindow == DateInterval(start: day(2026, 4, 4), end: day(2026, 4, 10)))
        #expect(p.upcomingPeriods.count == 3)
        #expect(p.upcomingPeriods[0] == DateInterval(start: day(2026, 4, 23), end: day(2026, 4, 27)))
        #expect(p.upcomingPeriods[1] == DateInterval(start: day(2026, 5, 21), end: day(2026, 5, 25)))
        #expect(p.upcomingPeriods[2] == DateInterval(start: day(2026, 6, 18), end: day(2026, 6, 22)))
    }

    @Test func slightlyLatePeriodIsNotRolledForward() {
        // Next = 2026-04-23; today 7 days past that — kept so UI can show "late".
        let p = CyclePredictor.prediction(from: regularCycles, today: day(2026, 4, 30), calendar: utc)!
        #expect(p.nextPeriodStart == day(2026, 4, 23))
    }

    @Test func longLapseRollsForward() {
        // Today 2026-07-01 is 69 days past 2026-04-23 (> 28): rolls to 05-21, still 41 past (> 28), rolls to 06-18 (13 past, kept).
        let p = CyclePredictor.prediction(from: regularCycles, today: day(2026, 7, 1), calendar: utc)!
        #expect(p.nextPeriodStart == day(2026, 6, 18))
    }

    @Test func implausibleCycleLengthsAreIgnored() {
        // 28, 90, 28 → only the two 28s count.
        var flow = flowRun(from: day(2026, 1, 1), count: 5)
        flow += flowRun(from: day(2026, 1, 29), count: 5)   // cycle 1: 28
        flow += flowRun(from: day(2026, 4, 29), count: 5)   // cycle 2: 90 (ignored)
        flow += flowRun(from: day(2026, 5, 27), count: 5)   // cycle 3: 28
        let cycles = CyclePredictor.cycles(fromFlowDays: flow, calendar: utc)
        let p = CyclePredictor.prediction(from: cycles, today: day(2026, 5, 30), calendar: utc)!
        #expect(p.averageCycleLength == 28)
    }

    @Test func implausiblePeriodLengthsAreIgnored() {
        // One 12-day "period" (data glitch) among 5-day periods.
        var flow = flowRun(from: day(2026, 1, 1), count: 12)
        flow += flowRun(from: day(2026, 1, 29), count: 5)
        flow += flowRun(from: day(2026, 2, 26), count: 5)
        let cycles = CyclePredictor.cycles(fromFlowDays: flow, calendar: utc)
        let p = CyclePredictor.prediction(from: cycles, today: day(2026, 3, 1), calendar: utc)!
        #expect(p.averagePeriodLength == 5)
    }

    @Test func onlyLastSixCyclesAreAveraged() {
        // Six 30-day cycles after two 20-day ones: average must be 30.
        var flow: [Date] = []
        var start = day(2025, 6, 1)
        for length in [20, 20, 30, 30, 30, 30, 30, 30] {
            flow += flowRun(from: start, count: 4)
            start = utc.date(byAdding: .day, value: length, to: start)!
        }
        flow += flowRun(from: start, count: 4)  // final open cycle
        let cycles = CyclePredictor.cycles(fromFlowDays: flow, calendar: utc)
        let p = CyclePredictor.prediction(from: cycles, today: start, calendar: utc)!
        #expect(p.averageCycleLength == 30)
    }
}
```

- [ ] **Step 2.2: Run the suite**

Run the test command. Expected: `** TEST SUCCEEDED **`, 12 tests passing. On any failure: recompute the expected value by hand from `CyclePredictor.swift`; only if the implementation is genuinely wrong, stop and report before changing it.

- [ ] **Step 2.3: Commit**

```bash
git add CycleSenseTests/CyclePredictorTests.swift
git commit -m "test: characterization suite for CyclePredictor"
```

---

## Sub-project 2: Logging expansion

### Task 3: Model types for new log data

**Files:**
- Modify: `CycleSense/Models/Models.swift`

- [ ] **Step 3.1: Add Cravings to Symptom**

In `enum Symptom`, add case `cravings` after `acne`; extend `displayName` with `case .cravings: return "Cravings"`, `systemImage` with `case .cravings: return "fork.knife"`. Add a new computed property after `systemImage` (HealthKit's appetiteChanges type is value-coded — 3 = increased — unlike the presence-style symptom types which use 0):

```swift
    /// Category value written to HealthKit for this symptom.
    /// Presence-style types use 0 ("unspecified/present"); appetiteChanges
    /// is value-coded, so cravings write 3 ("increased").
    var hkWriteValue: Int {
        self == .cravings ? 3 : 0
    }
```

- [ ] **Step 3.2: Add new log entry types at the end of Models.swift**

```swift
/// Feeling labels offered with a daily mood. Cases map 1:1 to
/// `HKStateOfMind.Label` values available on iOS 17 (see HealthKitManager).
enum MoodLabel: String, CaseIterable, Identifiable, Hashable {
    case calm, content, happy, stressed, irritated, anxious, sad, discouraged

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

/// One day's mood: valence on Apple's -1…1 pleasantness scale plus labels.
struct MoodEntry: Hashable {
    /// -1 (very unpleasant) … 1 (very pleasant).
    var valence: Double
    var labels: Set<MoodLabel>
}

/// Sexual activity for a day. `unspecified` covers samples from other apps
/// that carry no protection metadata.
enum SexualActivityEntry: String, CaseIterable, Identifiable, Hashable {
    case protected
    case unprotected
    case unspecified

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .protected: return "Protected"
        case .unprotected: return "Unprotected"
        case .unspecified: return "Unspecified"
        }
    }
}

/// Ovulation test result. Raw values match `HKCategoryValueOvulationTestResult`.
enum OvulationTestResult: Int, CaseIterable, Identifiable, Hashable {
    case negative = 1
    case luteinizingHormoneSurge = 2
    case indeterminate = 3
    case estrogenSurge = 4

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .negative: return "Negative"
        case .luteinizingHormoneSurge: return "LH surge"
        case .indeterminate: return "Indeterminate"
        case .estrogenSurge: return "Estrogen surge"
        }
    }
}

/// Everything the log sheet can save for one day. Nil means "not logged" —
/// saving nil clears this app's samples of that type for the day.
struct DayLogEntry {
    var flow: FlowLevel?
    var symptoms: Set<Symptom> = []
    var mood: MoodEntry?
    var weightKg: Double?
    var bbtCelsius: Double?
    var sexualActivity: SexualActivityEntry?
    var ovulationTest: OvulationTestResult?
}
```

- [ ] **Step 3.3: Build to verify it compiles**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3.4: Commit**

```bash
git add CycleSense/Models/Models.swift
git commit -m "feat: model types for mood, weight, BBT, sex, ovulation test, cravings"
```

### Task 4: HealthKitManager — authorization and write paths

**Files:**
- Modify: `CycleSense/Health/HealthKitManager.swift`

- [ ] **Step 4.1: Add type accessors**

After the `symptomIdentifiers` dictionary / `type(for:)`, add:

```swift
    private var weightType: HKQuantityType { HKQuantityType(.bodyMass) }
    private var bbtType: HKQuantityType { HKQuantityType(.basalBodyTemperature) }
    private var sexType: HKCategoryType { HKCategoryType(.sexualActivity) }
    private var ovulationTestType: HKCategoryType { HKCategoryType(.ovulationTestResult) }
    private var moodType: HKSampleType { HKObjectType.stateOfMindType() }

    private static let moodLabelMap: [MoodLabel: HKStateOfMind.Label] = [
        .calm: .calm, .content: .content, .happy: .happy, .stressed: .stressed,
        .irritated: .irritated, .anxious: .anxious, .sad: .sad, .discouraged: .discouraged,
    ]
```

Also map `.cravings` in `symptomIdentifiers`: add `.cravings: .appetiteChanges,`.

- [ ] **Step 4.2: Expand requestAuthorization**

Replace the body of `requestAuthorization()` with:

```swift
        var shareTypes: Set<HKSampleType> = [flowType, weightType, bbtType, sexType, ovulationTestType, moodType]
        var readTypes: Set<HKObjectType> = [flowType, weightType, bbtType, sexType, ovulationTestType, moodType]
        for symptom in Symptom.allCases {
            let categoryType = type(for: symptom)
            shareTypes.insert(categoryType)
            readTypes.insert(categoryType)
        }
        try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
```

- [ ] **Step 4.3: Fix saveSymptoms to use per-symptom write values**

In `saveSymptoms`, replace the sample-creation line with:

```swift
                let sample = HKCategorySample(type: categoryType, value: symptom.hkWriteValue, start: dayStart, end: dayStart)
```

(and delete the now-stale `// 0 means "unspecified"…` comment).

- [ ] **Step 4.4: Add write/delete methods for the new types**

Add a new `// MARK: - Writing (expanded log)` section after `saveSymptoms`:

```swift
    /// Replaces this app's body-mass sample for the day.
    func saveWeight(_ kilograms: Double?, on day: Date) async throws {
        let dayStart = Calendar.current.startOfDay(for: day)
        try await deleteOwnSamples(of: weightType, on: dayStart)
        guard let kilograms else { return }
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kilograms)
        let sample = HKQuantitySample(type: weightType, quantity: quantity, start: dayStart, end: dayStart)
        try await healthStore.save(sample)
    }

    /// Replaces this app's basal body temperature sample for the day.
    func saveBBT(_ celsius: Double?, on day: Date) async throws {
        let dayStart = Calendar.current.startOfDay(for: day)
        try await deleteOwnSamples(of: bbtType, on: dayStart)
        guard let celsius else { return }
        let quantity = HKQuantity(unit: .degreeCelsius(), doubleValue: celsius)
        let sample = HKQuantitySample(type: bbtType, quantity: quantity, start: dayStart, end: dayStart)
        try await healthStore.save(sample)
    }

    /// Replaces this app's sexual-activity sample for the day.
    func saveSexualActivity(_ entry: SexualActivityEntry?, on day: Date) async throws {
        let dayStart = Calendar.current.startOfDay(for: day)
        try await deleteOwnSamples(of: sexType, on: dayStart)
        guard let entry else { return }
        var metadata: [String: Any] = [:]
        switch entry {
        case .protected: metadata[HKMetadataKeySexualActivityProtectionUsed] = true
        case .unprotected: metadata[HKMetadataKeySexualActivityProtectionUsed] = false
        case .unspecified: break
        }
        let sample = HKCategorySample(
            type: sexType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: dayStart,
            end: dayStart,
            metadata: metadata.isEmpty ? nil : metadata
        )
        try await healthStore.save(sample)
    }

    /// Replaces this app's ovulation test result for the day.
    func saveOvulationTest(_ result: OvulationTestResult?, on day: Date) async throws {
        let dayStart = Calendar.current.startOfDay(for: day)
        try await deleteOwnSamples(of: ovulationTestType, on: dayStart)
        guard let result else { return }
        let sample = HKCategorySample(type: ovulationTestType, value: result.rawValue, start: dayStart, end: dayStart)
        try await healthStore.save(sample)
    }

    /// Replaces this app's daily-mood State of Mind sample for the day.
    func saveMood(_ mood: MoodEntry?, on day: Date) async throws {
        let dayStart = Calendar.current.startOfDay(for: day)
        try await deleteOwnSamples(of: moodType, on: dayStart)
        guard let mood else { return }
        let labels = mood.labels.compactMap { Self.moodLabelMap[$0] }
        let sample = HKStateOfMind(
            date: dayStart,
            kind: .dailyMood,
            valence: mood.valence,
            labels: labels,
            associations: []
        )
        try await healthStore.save(sample)
    }
```

- [ ] **Step 4.5: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4.6: Commit**

```bash
git add CycleSense/Health/HealthKitManager.swift
git commit -m "feat: HealthKit write paths for weight, BBT, sex, ovulation test, mood"
```

### Task 5: HealthKitManager — read paths

**Files:**
- Modify: `CycleSense/Health/HealthKitManager.swift`

- [ ] **Step 5.1: Add day-bucketed fetchers after fetchSymptomsByDay**

```swift
    /// Latest body-mass reading per day, in kilograms.
    func fetchWeightByDay(monthsBack: Int = 24) async throws -> [Date: Double] {
        try await fetchQuantityByDay(type: weightType, unit: .gramUnit(with: .kilo), monthsBack: monthsBack)
    }

    /// Latest basal body temperature per day, in °C.
    func fetchBBTByDay(monthsBack: Int = 24) async throws -> [Date: Double] {
        try await fetchQuantityByDay(type: bbtType, unit: .degreeCelsius(), monthsBack: monthsBack)
    }

    private func fetchQuantityByDay(type: HKQuantityType, unit: HKUnit, monthsBack: Int) async throws -> [Date: Double] {
        let calendar = Calendar.current
        let (start, end) = queryRange(monthsBack: monthsBack, calendar: calendar)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: healthStore)
        var byDay: [Date: Double] = [:]
        for sample in samples {
            // Sorted ascending, so the latest sample of the day wins.
            byDay[calendar.startOfDay(for: sample.startDate)] = sample.quantity.doubleValue(for: unit)
        }
        return byDay
    }

    /// Sexual activity per day. Protection metadata maps to the entry case.
    func fetchSexualActivityByDay(monthsBack: Int = 24) async throws -> [Date: SexualActivityEntry] {
        let calendar = Calendar.current
        let (start, end) = queryRange(monthsBack: monthsBack, calendar: calendar)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sexType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: healthStore)
        var byDay: [Date: SexualActivityEntry] = [:]
        for sample in samples {
            let entry: SexualActivityEntry
            if let used = sample.metadata?[HKMetadataKeySexualActivityProtectionUsed] as? Bool {
                entry = used ? .protected : .unprotected
            } else {
                entry = .unspecified
            }
            byDay[calendar.startOfDay(for: sample.startDate)] = entry
        }
        return byDay
    }

    /// Ovulation test results per day.
    func fetchOvulationTestsByDay(monthsBack: Int = 24) async throws -> [Date: OvulationTestResult] {
        let calendar = Calendar.current
        let (start, end) = queryRange(monthsBack: monthsBack, calendar: calendar)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: ovulationTestType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: healthStore)
        var byDay: [Date: OvulationTestResult] = [:]
        for sample in samples {
            guard let result = OvulationTestResult(rawValue: sample.value) else { continue }
            byDay[calendar.startOfDay(for: sample.startDate)] = result
        }
        return byDay
    }

    /// Daily-mood State of Mind entries per day.
    func fetchMoodByDay(monthsBack: Int = 24) async throws -> [Date: MoodEntry] {
        let calendar = Calendar.current
        let (start, end) = queryRange(monthsBack: monthsBack, calendar: calendar)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.stateOfMind(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: healthStore)
        var byDay: [Date: MoodEntry] = [:]
        let reverseLabelMap = Dictionary(uniqueKeysWithValues: Self.moodLabelMap.map { ($1, $0) })
        for sample in samples where sample.kind == .dailyMood {
            let labels = Set(sample.labels.compactMap { reverseLabelMap[$0] })
            byDay[calendar.startOfDay(for: sample.startDate)] = MoodEntry(valence: sample.valence, labels: labels)
        }
        return byDay
    }
```

Note: `fetchSymptomsByDay` needs no change for cravings — `.cravings` is in `Symptom.allCases`, and its "not logged" value (1 = no change) is already skipped by the existing `sample.value != 1` guard.

- [ ] **Step 5.2: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5.3: Commit**

```bash
git add CycleSense/Health/HealthKitManager.swift
git commit -m "feat: HealthKit read paths for expanded log data"
```

### Task 6: CycleStore — state, refresh, and unified logging

**Files:**
- Modify: `CycleSense/Store/CycleStore.swift`

- [ ] **Step 6.1: Add published state**

After `symptomsByDay`, add:

```swift
    /// Expanded log data keyed by start-of-day.
    @Published private(set) var moodByDay: [Date: MoodEntry] = [:]
    @Published private(set) var weightByDay: [Date: Double] = [:]
    @Published private(set) var bbtByDay: [Date: Double] = [:]
    @Published private(set) var sexByDay: [Date: SexualActivityEntry] = [:]
    @Published private(set) var ovulationTestByDay: [Date: OvulationTestResult] = [:]
```

- [ ] **Step 6.2: Extend refresh()**

Replace the `do` block of `refresh()` with:

```swift
        do {
            async let flow = manager.fetchFlowByDay(monthsBack: 24)
            async let symptoms = manager.fetchSymptomsByDay(monthsBack: 24)
            async let mood = manager.fetchMoodByDay(monthsBack: 24)
            async let weight = manager.fetchWeightByDay(monthsBack: 24)
            async let bbt = manager.fetchBBTByDay(monthsBack: 24)
            async let sex = manager.fetchSexualActivityByDay(monthsBack: 24)
            async let ovulation = manager.fetchOvulationTestsByDay(monthsBack: 24)
            flowByDay = try await flow
            symptomsByDay = try await symptoms
            moodByDay = try await mood
            weightByDay = try await weight
            bbtByDay = try await bbt
            sexByDay = try await sex
            ovulationTestByDay = try await ovulation
            recompute()
        } catch {
            lastError = error.localizedDescription
        }
```

- [ ] **Step 6.3: Replace logDay with the entry-based version**

Replace the whole `func logDay(_ day: Date, flow: FlowLevel?, symptoms: Set<Symptom>) async` with:

```swift
    /// Saves one day's full log entry to HealthKit and updates local state.
    /// Nil fields clear this app's samples of that type for the day.
    func logDay(_ day: Date, entry: DayLogEntry) async {
        let dayStart = calendar.startOfDay(for: day)
        do {
            if let flow = entry.flow {
                // First day of a period if the previous day has no flow logged.
                // Backfilling an earlier day can leave the next day's metadata
                // stale; the grouping in CyclePredictor does not rely on it.
                let previousDay = calendar.date(byAdding: .day, value: -1, to: dayStart)
                let isCycleStart = previousDay.map { flowByDay[$0] == nil } ?? true
                try await manager.saveFlow(flow, on: dayStart, cycleStart: isCycleStart)
                flowByDay[dayStart] = flow
            } else {
                try await manager.deleteFlow(on: dayStart)
                // If the flow came from another app, it will reappear on the
                // next refresh — HealthKit only lets us delete our own samples.
                flowByDay.removeValue(forKey: dayStart)
            }
            try await manager.saveMood(entry.mood, on: dayStart)
            try await manager.saveWeight(entry.weightKg, on: dayStart)
            try await manager.saveBBT(entry.bbtCelsius, on: dayStart)
            try await manager.saveSexualActivity(entry.sexualActivity, on: dayStart)
            try await manager.saveOvulationTest(entry.ovulationTest, on: dayStart)
        } catch {
            lastError = error.localizedDescription
        }
        await manager.saveSymptoms(entry.symptoms, on: dayStart)

        setOrRemove(entry.symptoms.isEmpty ? nil : entry.symptoms, in: &symptomsByDay, at: dayStart)
        setOrRemove(entry.mood, in: &moodByDay, at: dayStart)
        setOrRemove(entry.weightKg, in: &weightByDay, at: dayStart)
        setOrRemove(entry.bbtCelsius, in: &bbtByDay, at: dayStart)
        setOrRemove(entry.sexualActivity, in: &sexByDay, at: dayStart)
        setOrRemove(entry.ovulationTest, in: &ovulationTestByDay, at: dayStart)
        recompute()
    }

    private func setOrRemove<V>(_ value: V?, in dict: inout [Date: V], at key: Date) {
        if let value {
            dict[key] = value
        } else {
            dict.removeValue(forKey: key)
        }
    }
```

- [ ] **Step 6.4: Add per-day accessors**

After `func flow(on:)`, add:

```swift
    func dayLogEntry(on date: Date) -> DayLogEntry {
        let day = calendar.startOfDay(for: date)
        return DayLogEntry(
            flow: flowByDay[day],
            symptoms: symptomsByDay[day] ?? [],
            mood: moodByDay[day],
            weightKg: weightByDay[day],
            bbtCelsius: bbtByDay[day],
            sexualActivity: sexByDay[day],
            ovulationTest: ovulationTestByDay[day]
        )
    }
```

- [ ] **Step 6.5: Build (expect LogView break), fix comes next task**

Run the build command. Expected: FAILS in `LogView.swift` (old `logDay(_:flow:symptoms:)` signature gone). This confirms the only caller is LogView. Do not commit yet.

### Task 7: LogView — grouped scroll with all sections

**Files:**
- Modify: `CycleSense/Views/LogView.swift`

- [ ] **Step 7.1: Replace state and add unit helpers**

Replace the `@State` block (`flow`, `symptoms`, `isSaving`, `hasLoaded`) with:

```swift
    @State private var flow: FlowLevel?
    @State private var symptoms: Set<Symptom> = []
    @State private var moodLogged = false
    @State private var moodValence: Double = 0
    @State private var moodLabels: Set<MoodLabel> = []
    @State private var weightText = ""
    @State private var bbtText = ""
    @State private var sexualActivity: SexualActivityEntry?
    @State private var ovulationTest: OvulationTestResult?
    @State private var bodyExpanded = false
    @State private var ovulationExpanded = false
    @State private var isSaving = false
    @State private var hasLoaded = false

    private var usesImperialUnits: Bool {
        Locale.current.measurementSystem == .us
    }
    private var weightUnitLabel: String { usesImperialUnits ? "lb" : "kg" }
    private var bbtUnitLabel: String { usesImperialUnits ? "°F" : "°C" }

    private static let kgPerPound = 0.45359237

    private func kgFromInput(_ text: String) -> Double? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")), value > 0 else { return nil }
        return usesImperialUnits ? value * Self.kgPerPound : value
    }

    private func inputFromKg(_ kg: Double) -> String {
        let value = usesImperialUnits ? kg / Self.kgPerPound : kg
        return String(format: "%.1f", value)
    }

    private func celsiusFromInput(_ text: String) -> Double? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")) else { return nil }
        let celsius = usesImperialUnits ? (value - 32) * 5 / 9 : value
        // Plausible BBT range only; garbage input is dropped rather than saved.
        return (30...45).contains(celsius) ? celsius : nil
    }

    private func inputFromCelsius(_ celsius: Double) -> String {
        let value = usesImperialUnits ? celsius * 9 / 5 + 32 : celsius
        return String(format: "%.2f", value)
    }
```

- [ ] **Step 7.2: Add the new sections to the Form**

After the existing `Section("Symptoms") { … }`, add:

```swift
                Section("Mood") {
                    if moodLogged {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Unpleasant").font(.caption).foregroundStyle(.secondary)
                                Slider(value: $moodValence, in: -1...1, step: 0.1)
                                Text("Pleasant").font(.caption).foregroundStyle(.secondary)
                            }
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                                ForEach(MoodLabel.allCases) { label in
                                    moodChip(label)
                                }
                            }
                            Button("Clear mood", role: .destructive) {
                                moodLogged = false
                                moodValence = 0
                                moodLabels = []
                            }
                            .font(.footnote)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    } else {
                        Button("Log mood") { moodLogged = true }
                    }
                }

                Section("Sexual activity") {
                    HStack(spacing: 8) {
                        sexChip(nil, title: "None")
                        sexChip(.protected, title: "Protected")
                        sexChip(.unprotected, title: "Unprotected")
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                }

                Section {
                    DisclosureGroup("Body measurements", isExpanded: $bodyExpanded) {
                        LabeledContent("Weight") {
                            TextField("—", text: $weightText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                            Text(weightUnitLabel).foregroundStyle(.secondary)
                        }
                        LabeledContent("Basal temp") {
                            TextField("—", text: $bbtText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                            Text(bbtUnitLabel).foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    DisclosureGroup("Ovulation test", isExpanded: $ovulationExpanded) {
                        ForEach(OvulationTestResult.allCases) { result in
                            Button {
                                ovulationTest = ovulationTest == result ? nil : result
                            } label: {
                                HStack {
                                    Text(result.displayName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if ovulationTest == result {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.pink)
                                    }
                                }
                            }
                        }
                    }
                }
```

- [ ] **Step 7.3: Add the chip helpers**

After `symptomChip`, add:

```swift
    private func moodChip(_ label: MoodLabel) -> some View {
        let isSelected = moodLabels.contains(label)
        return Button {
            if isSelected { moodLabels.remove(label) } else { moodLabels.insert(label) }
        } label: {
            Text(label.displayName)
                .font(.footnote)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Color.indigo.opacity(0.85) : Color(.systemGray5), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func sexChip(_ value: SexualActivityEntry?, title: String) -> some View {
        let isSelected = sexualActivity == value
        return Button {
            sexualActivity = value
        } label: {
            Text(title)
                .font(.footnote)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.purple.opacity(0.85) : Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
```

Note: a stored `.unspecified` sexual-activity sample (from another app) shows as no chip selected; saving then clears it only if the user picks a chip — acceptable for now.

- [ ] **Step 7.4: Replace loadExisting and save**

```swift
    private func loadExisting() {
        guard !hasLoaded else { return }
        let entry = store.dayLogEntry(on: date)
        flow = entry.flow
        symptoms = entry.symptoms
        if let mood = entry.mood {
            moodLogged = true
            moodValence = mood.valence
            moodLabels = mood.labels
        }
        if let kg = entry.weightKg { weightText = inputFromKg(kg) }
        if let celsius = entry.bbtCelsius { bbtText = inputFromCelsius(celsius) }
        if entry.weightKg != nil || entry.bbtCelsius != nil { bodyExpanded = true }
        sexualActivity = entry.sexualActivity == .unspecified ? nil : entry.sexualActivity
        ovulationTest = entry.ovulationTest
        if entry.ovulationTest != nil { ovulationExpanded = true }
        hasLoaded = true
    }

    private func save() {
        isSaving = true
        let entry = DayLogEntry(
            flow: flow,
            symptoms: symptoms,
            mood: moodLogged ? MoodEntry(valence: moodValence, labels: moodLabels) : nil,
            weightKg: kgFromInput(weightText),
            bbtCelsius: celsiusFromInput(bbtText),
            sexualActivity: sexualActivity,
            ovulationTest: ovulationTest
        )
        Task {
            await store.logDay(date, entry: entry)
            isSaving = false
            dismiss()
        }
    }
```

- [ ] **Step 7.5: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7.6: Commit**

```bash
git add CycleSense/Store/CycleStore.swift CycleSense/Views/LogView.swift
git commit -m "feat: expanded log sheet — mood, sex, body measurements, ovulation test"
```

### Task 8: TodayView card + simulator verification

**Files:**
- Modify: `CycleSense/Views/TodayView.swift:122-156` (todayCard)

- [ ] **Step 8.1: Extend todayCard**

Replace the `todayCard` computed property body's data lines with:

```swift
    private var todayCard: some View {
        let entry = store.dayLogEntry(on: Date())
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's log")
                    .font(.headline)
                Spacer()
                Button("Log") { showingLog = true }
                    .font(.subheadline.bold())
            }
            if let flow = entry.flow {
                Label("\(flow.displayName) flow", systemImage: "drop.fill")
                    .foregroundStyle(.red)
                    .font(.subheadline)
            }
            if !entry.symptoms.isEmpty {
                Label(
                    entry.symptoms.sorted { $0.displayName < $1.displayName }
                        .map(\.displayName)
                        .joined(separator: ", "),
                    systemImage: "heart.text.square"
                )
                .font(.subheadline)
            }
            if let mood = entry.mood {
                Label(moodSummary(mood), systemImage: "face.smiling")
                    .foregroundStyle(.indigo)
                    .font(.subheadline)
            }
            if let sex = entry.sexualActivity {
                Label("Sexual activity (\(sex.displayName.lowercased()))", systemImage: "heart.fill")
                    .foregroundStyle(.purple)
                    .font(.subheadline)
            }
            if let kg = entry.weightKg {
                Label(formattedWeight(kg), systemImage: "scalemass")
                    .font(.subheadline)
            }
            if let celsius = entry.bbtCelsius {
                Label(formattedTemperature(celsius), systemImage: "thermometer.variable.and.figure")
                    .font(.subheadline)
            }
            if let test = entry.ovulationTest {
                Label("Ovulation test: \(test.displayName)", systemImage: "testtube.2")
                    .foregroundStyle(.teal)
                    .font(.subheadline)
            }
            if entryIsEmpty(entry) {
                Text("Nothing logged yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func entryIsEmpty(_ entry: DayLogEntry) -> Bool {
        entry.flow == nil && entry.symptoms.isEmpty && entry.mood == nil
            && entry.weightKg == nil && entry.bbtCelsius == nil
            && entry.sexualActivity == nil && entry.ovulationTest == nil
    }

    private func moodSummary(_ mood: MoodEntry) -> String {
        let tone: String
        switch mood.valence {
        case ..<(-0.33): tone = "Unpleasant"
        case 0.33...: tone = "Pleasant"
        default: tone = "Neutral"
        }
        let labels = mood.labels.sorted { $0.displayName < $1.displayName }.map(\.displayName)
        return labels.isEmpty ? "\(tone) mood" : "\(tone) mood — \(labels.joined(separator: ", "))"
    }

    private func formattedWeight(_ kg: Double) -> String {
        Measurement(value: kg, unit: UnitMass.kilograms)
            .formatted(.measurement(width: .abbreviated, usage: .personWeight))
    }

    private func formattedTemperature(_ celsius: Double) -> String {
        "Basal temp " + Measurement(value: celsius, unit: UnitTemperature.celsius)
            .formatted(.measurement(width: .abbreviated, usage: .person))
    }
```

- [ ] **Step 8.2: Build, install, launch on simulator**

Build, then install and relaunch on the booted simulator. Expected: app launches to Today view.

- [ ] **Step 8.3: Drive the new flow**

Open Log sheet; the new Health permission sheet appears (new types) — grant all. Log: mood (slider + 2 labels), sex = protected, expand Body, enter weight and BBT, ovulation test = LH surge. Save. Screenshot. Expected: Today card lists mood, sex, weight, temp, test lines. Kill + relaunch; data must survive (HealthKit read-back).

- [ ] **Step 8.4: Run unit tests (regression)**

Run the test command. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 8.5: Commit**

```bash
git add CycleSense/Views/TodayView.swift
git commit -m "feat: today card shows expanded log entries"
```

---

## Sub-project 3: Notifications

### Task 9: ReminderPlanner (pure) + tests

**Files:**
- Create: `CycleSense/Logic/ReminderPlanner.swift`
- Create: `CycleSenseTests/ReminderPlannerTests.swift`

- [ ] **Step 9.1: Write the failing tests**

`CycleSenseTests/ReminderPlannerTests.swift`:

```swift
import Foundation
import Testing
@testable import CycleSense

private let utc: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal
}()

private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
    utc.date(from: DateComponents(year: y, month: m, day: d))!
}

private func at9(_ y: Int, _ m: Int, _ d: Int) -> Date {
    utc.date(from: DateComponents(year: y, month: m, day: d, hour: 9))!
}

private func makePrediction(nextPeriod: Date, fertileStart: Date?) -> Prediction {
    Prediction(
        averageCycleLength: 28,
        averagePeriodLength: 5,
        nextPeriodStart: nextPeriod,
        upcomingPeriods: [],
        ovulationDate: nil,
        fertileWindow: fertileStart.map { DateInterval(start: $0, duration: 6 * 86400) }
    )
}

@Suite struct ReminderPlannerTests {
    @Test func fullSetWhenEverythingEnabledAndFuture() {
        let p = makePrediction(nextPeriod: day(2026, 8, 20), fertileStart: day(2026, 8, 9))
        let reminders = ReminderPlanner.reminders(
            for: p, periodEnabled: true, fertileEnabled: true,
            now: day(2026, 8, 1), calendar: utc
        )
        #expect(reminders.map(\.id) == ["fertile-start", "period-2d", "period-0d"])
        #expect(reminders.first { $0.id == "period-2d" }!.fireDate == at9(2026, 8, 18))
        #expect(reminders.first { $0.id == "period-0d" }!.fireDate == at9(2026, 8, 20))
        #expect(reminders.first { $0.id == "fertile-start" }!.fireDate == at9(2026, 8, 9))
    }

    @Test func disabledTogglesDropTheirReminders() {
        let p = makePrediction(nextPeriod: day(2026, 8, 20), fertileStart: day(2026, 8, 9))
        let periodOnly = ReminderPlanner.reminders(
            for: p, periodEnabled: true, fertileEnabled: false,
            now: day(2026, 8, 1), calendar: utc
        )
        #expect(periodOnly.map(\.id) == ["period-2d", "period-0d"])
        let none = ReminderPlanner.reminders(
            for: p, periodEnabled: false, fertileEnabled: false,
            now: day(2026, 8, 1), calendar: utc
        )
        #expect(none.isEmpty)
    }

    @Test func pastFireDatesAreSkipped() {
        // Period on Aug 20; "now" is Aug 19 at noon → the 2-days-before slot
        // (Aug 18, 09:00) is past and must be dropped; day-of remains.
        let now = utc.date(from: DateComponents(year: 2026, month: 8, day: 19, hour: 12))!
        let p = makePrediction(nextPeriod: day(2026, 8, 20), fertileStart: day(2026, 8, 9))
        let reminders = ReminderPlanner.reminders(
            for: p, periodEnabled: true, fertileEnabled: true,
            now: now, calendar: utc
        )
        #expect(reminders.map(\.id) == ["period-0d"])
    }

    @Test func missingFertileWindowGivesNoFertileReminder() {
        let p = makePrediction(nextPeriod: day(2026, 8, 20), fertileStart: nil)
        let reminders = ReminderPlanner.reminders(
            for: p, periodEnabled: true, fertileEnabled: true,
            now: day(2026, 8, 1), calendar: utc
        )
        #expect(!reminders.contains { $0.id == "fertile-start" })
    }
}
```

- [ ] **Step 9.2: Run tests, expect compile failure**

Run the test command. Expected: FAIL — `ReminderPlanner` not defined.

- [ ] **Step 9.3: Implement ReminderPlanner**

`CycleSense/Logic/ReminderPlanner.swift`:

```swift
import Foundation

/// A single planned local notification. Pure data — scheduling lives in
/// NotificationScheduler so this stays unit-testable.
struct PlannedReminder: Equatable {
    /// Stable identifier; re-scheduling replaces requests by these ids.
    let id: String
    let fireDate: Date
    let title: String
    let body: String
}

/// Turns a `Prediction` into the set of local reminders to schedule.
/// Deterministic and side-effect free.
enum ReminderPlanner {
    static let allIdentifiers = ["fertile-start", "period-2d", "period-0d"]
    /// Reminders fire at 09:00 local time.
    static let fireHour = 9

    static func reminders(
        for prediction: Prediction,
        periodEnabled: Bool,
        fertileEnabled: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PlannedReminder] {
        var result: [PlannedReminder] = []

        func fireDate(onDay day: Date) -> Date? {
            calendar.date(bySettingHour: fireHour, minute: 0, second: 0, of: calendar.startOfDay(for: day))
        }

        if fertileEnabled, let windowStart = prediction.fertileWindow?.start,
           let date = fireDate(onDay: windowStart), date > now {
            result.append(PlannedReminder(
                id: "fertile-start",
                fireDate: date,
                title: "Fertile window opening",
                body: "Your estimated fertile window starts today."
            ))
        }

        if periodEnabled {
            if let twoBefore = calendar.date(byAdding: .day, value: -2, to: prediction.nextPeriodStart),
               let date = fireDate(onDay: twoBefore), date > now {
                result.append(PlannedReminder(
                    id: "period-2d",
                    fireDate: date,
                    title: "Period soon",
                    body: "Your period is estimated to start in 2 days."
                ))
            }
            if let date = fireDate(onDay: prediction.nextPeriodStart), date > now {
                result.append(PlannedReminder(
                    id: "period-0d",
                    fireDate: date,
                    title: "Period expected today",
                    body: "Your period is estimated to start today."
                ))
            }
        }

        return result
    }
}
```

- [ ] **Step 9.4: Run tests**

Run the test command. Expected: `** TEST SUCCEEDED **` (16 tests).

- [ ] **Step 9.5: Commit**

```bash
git add CycleSense/Logic/ReminderPlanner.swift CycleSenseTests/ReminderPlannerTests.swift
git commit -m "feat: pure reminder planning with tests"
```

### Task 10: NotificationScheduler + store hook + Settings UI

**Files:**
- Create: `CycleSense/Health/NotificationScheduler.swift`
- Modify: `CycleSense/Store/CycleStore.swift` (recompute hook)
- Modify: `CycleSense/Views/SettingsView.swift` (Reminders section)

- [ ] **Step 10.1: Implement the scheduler**

`CycleSense/Health/NotificationScheduler.swift`:

```swift
import Foundation
import UserNotifications

/// Thin wrapper around UNUserNotificationCenter: replaces the app's pending
/// cycle reminders with a freshly planned set.
enum NotificationScheduler {
    /// UserDefaults keys for the Settings toggles. CycleStore reads them too.
    static let periodEnabledKey = "periodReminderEnabled"
    static let fertileEnabledKey = "fertileReminderEnabled"

    /// Asks for alert/sound permission. Returns whether it is granted.
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func permissionDenied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    /// Replaces all cycle reminders with the given plan.
    static func apply(_ reminders: [PlannedReminder], calendar: Calendar = .current) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ReminderPlanner.allIdentifiers)
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    /// Plans from the current prediction + toggle state, then applies.
    static func reschedule(prediction: Prediction?, defaults: UserDefaults = .standard) async {
        let periodEnabled = defaults.bool(forKey: periodEnabledKey)
        let fertileEnabled = defaults.bool(forKey: fertileEnabledKey)
        guard let prediction, periodEnabled || fertileEnabled else {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ReminderPlanner.allIdentifiers)
            return
        }
        let planned = ReminderPlanner.reminders(
            for: prediction,
            periodEnabled: periodEnabled,
            fertileEnabled: fertileEnabled
        )
        await apply(planned)
    }
}
```

- [ ] **Step 10.2: Hook into CycleStore.recompute**

Replace `recompute()` in `CycleSense/Store/CycleStore.swift` with:

```swift
    private func recompute() {
        cycles = CyclePredictor.cycles(fromFlowDays: Array(flowByDay.keys), calendar: calendar)
        prediction = CyclePredictor.prediction(from: cycles, today: Date(), calendar: calendar)
        let currentPrediction = prediction
        Task { await NotificationScheduler.reschedule(prediction: currentPrediction) }
    }
```

- [ ] **Step 10.3: Add Reminders section to SettingsView**

In `CycleSense/Views/SettingsView.swift`, add state and toggles. After the `@Environment(\.openURL)` line add:

```swift
    @AppStorage(NotificationScheduler.periodEnabledKey) private var periodReminders = false
    @AppStorage(NotificationScheduler.fertileEnabledKey) private var fertileReminders = false
    @State private var notificationsDenied = false
```

After the Apple Health section (before the refresh section), add:

```swift
                Section {
                    Toggle("Period reminders", isOn: $periodReminders)
                    Toggle("Fertile window reminder", isOn: $fertileReminders)
                    if notificationsDenied && (periodReminders || fertileReminders) {
                        Button("Enable notifications in Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        }
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Period reminders arrive 2 days before and on the estimated start day, at 9:00. The fertile reminder arrives when the estimated window opens.")
                }
```

Add the change handlers + permission check to the `List` (after `.navigationTitle("Settings")`):

```swift
            .task { notificationsDenied = await NotificationScheduler.permissionDenied() }
            .onChange(of: periodReminders) { _, _ in remindersChanged() }
            .onChange(of: fertileReminders) { _, _ in remindersChanged() }
```

And add the helper method to the struct:

```swift
    private func remindersChanged() {
        Task {
            if periodReminders || fertileReminders {
                _ = await NotificationScheduler.requestPermission()
                notificationsDenied = await NotificationScheduler.permissionDenied()
            }
            await NotificationScheduler.reschedule(prediction: store.prediction)
        }
    }
```

Also add `import UIKit` is unnecessary (SwiftUI re-exports what's needed; `UIApplication.openSettingsURLString` needs UIKit — SwiftUI imports it transitively on iOS, so no extra import).

- [ ] **Step 10.4: Build + tests**

Run build and test commands. Expected: both succeed.

- [ ] **Step 10.5: Simulator verification**

Install + launch. Settings tab → enable "Period reminders" → system permission alert appears → Allow. Screenshot. Expected: both toggles interactable, toggle stays on, and no "Enable notifications in Settings" row appears. There is no simctl API to list pending local notifications, so trigger-date correctness rests on the ReminderPlanner unit tests; this step verifies the permission flow and UI wiring only.

- [ ] **Step 10.6: Commit**

```bash
git add CycleSense/Health/NotificationScheduler.swift CycleSense/Store/CycleStore.swift CycleSense/Views/SettingsView.swift
git commit -m "feat: period and fertile-window local reminders"
```

---

## Sub-project 4: Home Screen widget

### Task 11: Shared snapshot model + test

**Files:**
- Create: `CycleSenseShared/WidgetSnapshot.swift` (new top-level folder — shared between app and widget targets)
- Create: `CycleSenseTests/WidgetSnapshotTests.swift`
- Modify: `CycleSense.xcodeproj/project.pbxproj` (register shared folder in app target; widget target comes in Task 12)

- [ ] **Step 11.1: Write the failing round-trip test**

`CycleSenseTests/WidgetSnapshotTests.swift`:

```swift
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
```

- [ ] **Step 11.2: Run tests, expect compile failure**

Expected: FAIL — `WidgetSnapshot` not defined.

- [ ] **Step 11.3: Implement the shared model**

`CycleSenseShared/WidgetSnapshot.swift`:

```swift
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
```

- [ ] **Step 11.4: Register CycleSenseShared with the app target in project.pbxproj**

Add to the `PBXFileSystemSynchronizedRootGroup` section:

```
		AB000000000000000000001A /* CycleSenseShared */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			explicitFileTypes = {
			};
			explicitFolders = (
			);
			path = CycleSenseShared;
			sourceTree = "<group>";
		};
```

Add `AB000000000000000000001A /* CycleSenseShared */,` to the main group's `children` and to the app target `AB0000000000000000000006`'s `fileSystemSynchronizedGroups`.

- [ ] **Step 11.5: Run tests**

Expected: `** TEST SUCCEEDED **` (18 tests).

- [ ] **Step 11.6: Commit**

```bash
git add CycleSenseShared CycleSenseTests/WidgetSnapshotTests.swift CycleSense.xcodeproj
git commit -m "feat: shared widget snapshot model"
```

### Task 12: Widget extension target

**Files:**
- Create: `CycleSenseWidget/CycleSenseWidgetBundle.swift`
- Create: `CycleSenseWidget/CycleSenseWidget.swift`
- Create: `CycleSenseWidget/Info.plist`
- Create: `CycleSenseWidget/CycleSenseWidget.entitlements`
- Modify: `CycleSense/CycleSense.entitlements` (app group)
- Modify: `CycleSense.xcodeproj/project.pbxproj` (widget target + embed)

- [ ] **Step 12.1: Widget sources**

`CycleSenseWidget/CycleSenseWidgetBundle.swift`:

```swift
import SwiftUI
import WidgetKit

@main
struct CycleSenseWidgetBundle: WidgetBundle {
    var body: some Widget {
        CycleSenseWidget()
    }
}
```

`CycleSenseWidget/CycleSenseWidget.swift`:

```swift
import SwiftUI
import WidgetKit

struct CycleEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct CycleProvider: TimelineProvider {
    func placeholder(in context: Context) -> CycleEntry {
        CycleEntry(date: .now, snapshot: WidgetSnapshot(
            cycleDay: 12, phase: "Follicular",
            nextPeriodStart: Calendar.current.date(byAdding: .day, value: 16, to: .now),
            fertileStart: nil, fertileEnd: nil, generatedAt: .now
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (CycleEntry) -> Void) {
        completion(CycleEntry(date: .now, snapshot: WidgetSnapshot.read(from: WidgetSnapshot.appGroupDefaults)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CycleEntry>) -> Void) {
        let entry = CycleEntry(date: .now, snapshot: WidgetSnapshot.read(from: WidgetSnapshot.appGroupDefaults))
        // The app pushes reloads on data changes; refresh at next midnight so
        // the cycle-day number stays correct even without app launches.
        let nextMidnight = Calendar.current.nextDate(
            after: .now, matching: DateComponents(hour: 0), matchingPolicy: .nextTime
        ) ?? .now.addingTimeInterval(86_400)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

struct CycleWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CycleEntry

    private var daysUntilNextPeriod: Int? {
        guard let next = entry.snapshot?.nextPeriodStart else { return nil }
        return Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: entry.date),
            to: Calendar.current.startOfDay(for: next)
        ).day
    }

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, let cycleDay = snapshot.cycleDay {
                content(snapshot: snapshot, cycleDay: cycleDay)
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "heart.circle.fill")
                        .foregroundStyle(.pink)
                        .font(.title2)
                    Text("Open CycleSense to start tracking")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    private func content(snapshot: WidgetSnapshot, cycleDay: Int) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text("Day \(cycleDay)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let days = daysUntilNextPeriod {
                    Text(periodText(days))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            if family == .systemMedium {
                VStack(alignment: .leading, spacing: 6) {
                    if let phase = snapshot.phase {
                        Label("\(phase) phase", systemImage: "circle.hexagongrid.fill")
                            .font(.caption)
                            .foregroundStyle(.pink)
                    }
                    if let start = snapshot.fertileStart, let end = snapshot.fertileEnd {
                        Label(
                            "Fertile \(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))",
                            systemImage: "sparkles"
                        )
                        .font(.caption)
                        .foregroundStyle(.teal)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func periodText(_ days: Int) -> String {
        if days > 1 { return "Period in \(days) days" }
        if days == 1 { return "Period tomorrow" }
        if days == 0 { return "Period expected today" }
        return -days == 1 ? "1 day late" : "\(-days) days late"
    }
}

struct CycleSenseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CycleSenseWidget", provider: CycleProvider()) { entry in
            CycleWidgetView(entry: entry)
        }
        .configurationDisplayName("Cycle day")
        .description("Your current cycle day and next period estimate.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
```

- [ ] **Step 12.2: Widget Info.plist and entitlements**

`CycleSenseWidget/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.widgetkit-extension</string>
	</dict>
</dict>
</plist>
```

`CycleSenseWidget/CycleSenseWidget.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.example.CycleSense</string>
	</array>
</dict>
</plist>
```

Add the same `com.apple.security.application-groups` key/array to `CycleSense/CycleSense.entitlements` (keep the existing HealthKit keys).

- [ ] **Step 12.3: pbxproj — widget target**

All additions to `CycleSense.xcodeproj/project.pbxproj`:

`PBXFileSystemSynchronizedRootGroup` section — the widget folder, with an exception so Info.plist isn't compiled as a resource:

```
		AB000000000000000000001B /* CycleSenseWidget */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			exceptions = (
				AB000000000000000000002A /* Exceptions for "CycleSenseWidget" folder in "CycleSenseWidgetExtension" target */,
			);
			explicitFileTypes = {
			};
			explicitFolders = (
			);
			path = CycleSenseWidget;
			sourceTree = "<group>";
		};
```

New section (alphabetically it sits before PBXFileSystemSynchronizedRootGroup — placement between existing sections is fine):

```
/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */
		AB000000000000000000002A /* Exceptions for "CycleSenseWidget" folder in "CycleSenseWidgetExtension" target */ = {
			isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
			membershipExceptions = (
				Info.plist,
			);
			target = AB000000000000000000001C /* CycleSenseWidgetExtension */;
		};
/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */
```

`PBXFileReference` section:

```
		AB000000000000000000001D /* CycleSenseWidgetExtension.appex */ = {isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = CycleSenseWidgetExtension.appex; sourceTree = BUILT_PRODUCTS_DIR; };
```

Add `AB000000000000000000001D /* CycleSenseWidgetExtension.appex */,` to Products group children, `AB000000000000000000001B /* CycleSenseWidget */,` to main group children.

`PBXNativeTarget` section:

```
		AB000000000000000000001C /* CycleSenseWidgetExtension */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = AB000000000000000000001E /* Build configuration list for PBXNativeTarget "CycleSenseWidgetExtension" */;
			buildPhases = (
				AB000000000000000000001F /* Sources */,
				AB0000000000000000000020 /* Frameworks */,
				AB0000000000000000000021 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				AB000000000000000000001B /* CycleSenseWidget */,
				AB000000000000000000001A /* CycleSenseShared */,
			);
			name = CycleSenseWidgetExtension;
			packageProductDependencies = (
			);
			productName = CycleSenseWidgetExtension;
			productReference = AB000000000000000000001D /* CycleSenseWidgetExtension.appex */;
			productType = "com.apple.product-type.app-extension";
		};
```

Build phases (add to their sections):

```
		AB000000000000000000001F /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		AB0000000000000000000020 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		AB0000000000000000000021 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
```

Embed phase — add a `PBXCopyFilesBuildPhase` section and a `PBXBuildFile` section entry:

```
/* Begin PBXBuildFile section */
		AB0000000000000000000022 /* CycleSenseWidgetExtension.appex in Embed Foundation Extensions */ = {isa = PBXBuildFile; fileRef = AB000000000000000000001D /* CycleSenseWidgetExtension.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };
/* End PBXBuildFile section */

/* Begin PBXCopyFilesBuildPhase section */
		AB0000000000000000000023 /* Embed Foundation Extensions */ = {
			isa = PBXCopyFilesBuildPhase;
			buildActionMask = 2147483647;
			dstPath = "";
			dstSubfolderSpec = 13;
			files = (
				AB0000000000000000000022 /* CycleSenseWidgetExtension.appex in Embed Foundation Extensions */,
			);
			name = "Embed Foundation Extensions";
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXCopyFilesBuildPhase section */
```

App target `AB0000000000000000000006`: append `AB0000000000000000000023 /* Embed Foundation Extensions */,` to `buildPhases` (after Resources) and add to `dependencies`:

```
				AB0000000000000000000024 /* PBXTargetDependency */,
```

Target dependency + proxy (add to their sections):

```
		AB0000000000000000000024 /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = AB000000000000000000001C /* CycleSenseWidgetExtension */;
			targetProxy = AB0000000000000000000025 /* PBXContainerItemProxy */;
		};
		AB0000000000000000000025 /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = AB000000000000000000000A /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = AB000000000000000000001C;
			remoteInfo = CycleSenseWidgetExtension;
		};
```

`XCBuildConfiguration` section:

```
		AB0000000000000000000026 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = CycleSenseWidget/CycleSenseWidget.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = CycleSenseWidget/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = CycleSense;
				INFOPLIST_KEY_NSHumanReadableCopyright = "";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@executable_path/../../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.CycleSense.CycleSenseWidget;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SKIP_INSTALL = YES;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Debug;
		};
		AB0000000000000000000027 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = CycleSenseWidget/CycleSenseWidget.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = CycleSenseWidget/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = CycleSense;
				INFOPLIST_KEY_NSHumanReadableCopyright = "";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@executable_path/../../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.CycleSense.CycleSenseWidget;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SKIP_INSTALL = YES;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Release;
		};
```

`XCConfigurationList` section:

```
		AB000000000000000000001E /* Build configuration list for PBXNativeTarget "CycleSenseWidgetExtension" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				AB0000000000000000000026 /* Debug */,
				AB0000000000000000000027 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
```

`PBXProject`: add `AB000000000000000000001C /* CycleSenseWidgetExtension */,` to `targets`, and to `TargetAttributes`:

```
					AB000000000000000000001C = {
						CreatedOnToolsVersion = 16.0;
					};
```

- [ ] **Step 12.4: Build**

Run the build command. Expected: `** BUILD SUCCEEDED **` (app + embedded appex).

- [ ] **Step 12.5: Commit**

```bash
git add CycleSenseWidget CycleSense/CycleSense.entitlements CycleSense.xcodeproj
git commit -m "feat: Home Screen widget extension (small + medium)"
```

### Task 13: App writes the snapshot; end-to-end verification

**Files:**
- Modify: `CycleSense/Store/CycleStore.swift` (recompute)

- [ ] **Step 13.1: Write snapshot on every recompute**

Add `import WidgetKit` at the top of `CycleStore.swift`. Replace `recompute()` with:

```swift
    private func recompute() {
        cycles = CyclePredictor.cycles(fromFlowDays: Array(flowByDay.keys), calendar: calendar)
        prediction = CyclePredictor.prediction(from: cycles, today: Date(), calendar: calendar)
        let currentPrediction = prediction
        Task { await NotificationScheduler.reschedule(prediction: currentPrediction) }
        publishWidgetSnapshot()
    }

    private func publishWidgetSnapshot() {
        let snapshot = WidgetSnapshot(
            cycleDay: currentCycleDay,
            phase: currentPhase?.rawValue,
            nextPeriodStart: prediction?.nextPeriodStart,
            fertileStart: prediction?.fertileWindow?.start,
            fertileEnd: prediction?.fertileWindow?.end,
            generatedAt: Date()
        )
        snapshot.write(to: WidgetSnapshot.appGroupDefaults)
        WidgetCenter.shared.reloadAllTimelines()
    }
```

- [ ] **Step 13.2: Build + tests**

Run build and test commands. Expected: both succeed.

- [ ] **Step 13.3: Simulator end-to-end**

Install + launch app (writes snapshot on refresh). Then add the widget to the Home Screen — drive the simulator: long-press Home Screen background (`touch_path` with ~1s hold), tap Edit/+, search "CycleSense", add small widget. Screenshot: widget shows "Day N / Period in …". If widget gallery automation proves flaky, fall back to:

```bash
xcrun simctl launch 386E2C64-0E1E-4C7E-AFBF-8DCDFCA4A5AB com.example.CycleSense
```

plus verifying the snapshot file exists in the App Group container:

```bash
xcrun simctl get_app_container 386E2C64-0E1E-4C7E-AFBF-8DCDFCA4A5AB com.example.CycleSense data >/dev/null 2>&1; \
ls "$(xcrun simctl get_app_container 386E2C64-0E1E-4C7E-AFBF-8DCDFCA4A5AB com.example.CycleSense groups 2>/dev/null | grep -o '/.*group.com.example.CycleSense.*' | head -1)/Library/Preferences" 2>/dev/null || echo "check group container manually"
```

Expected: a `group.com.example.CycleSense.plist` containing the snapshot key.

- [ ] **Step 13.4: Commit**

```bash
git add CycleSense/Store/CycleStore.swift
git commit -m "feat: publish widget snapshot on every data refresh"
```

### Task 14: Final regression + docs

- [ ] **Step 14.1: Full test run + full build**

Run both commands. Expected: `** TEST SUCCEEDED **`, `** BUILD SUCCEEDED **`.

- [ ] **Step 14.2: Update README**

In `README.md`: add the new logged data types to the Features/Health-integration tables (weight → `bodyMass`, BBT → `basalBodyTemperature`, sex → `sexualActivity` + protection metadata, ovulation tests → `ovulationTestResult`, cravings → `appetiteChanges`, mood → State of Mind); add sections for Reminders and the Widget; move the delivered items out of "Ideas for next steps" (leaves: watchOS companion; add: cycle-length insights charts).

- [ ] **Step 14.3: Commit**

```bash
git add README.md
git commit -m "docs: README for expanded logging, reminders, widget"
```

---

## Self-review notes

- Spec coverage: tests (Task 1–2), logging expansion (3–8), notifications (9–10), widget (11–13), README (14). Insights untouched — matches spec.
- `logDay` signature change is breaking; LogView is its only caller (verified — Task 6 Step 6.5 relies on the compile error to prove it).
- Type-consistency check: `DayLogEntry`, `MoodEntry`, `MoodLabel`, `SexualActivityEntry`, `OvulationTestResult`, `PlannedReminder`, `WidgetSnapshot` names used identically across tasks. `NotificationScheduler.periodEnabledKey`/`fertileEnabledKey` shared between scheduler and SettingsView.
- pbxproj IDs `AB…10` – `AB…2A` are each used exactly once.
