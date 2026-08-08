import SwiftUI

/// Bento-style sheet for logging (or editing) one day.
/// Six tappable blocks expand in place; one open at a time.
struct LogView: View {
    private enum Block: String, CaseIterable, Identifiable {
        case flow, symptoms, mood, body, intimacy, test
        var id: String { rawValue }
    }

    @EnvironmentObject private var store: CycleStore
    @Environment(\.dismiss) private var dismiss

    let date: Date

    @State private var flow: FlowLevel?
    @State private var symptoms: Set<Symptom> = []
    @State private var moodLogged = false
    @State private var moodValence: Double = 0
    @State private var moodLabels: Set<MoodLabel> = []
    @State private var weightText = ""
    @State private var bbtText = ""
    @State private var sexualActivity: SexualActivityEntry?
    @State private var ovulationTest: OvulationTestResult?
    @State private var expandedBlock: Block?
    @State private var isSaving = false
    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        blockGrid
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 90)
                }
                saveBar
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                        .foregroundStyle(Theme.body)
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("today's check-in")
                .font(Theme.title())
                .foregroundStyle(Theme.ink)
            Text(date.formatted(date: .complete, time: .omitted).lowercased())
                .font(.footnote)
                .foregroundStyle(Theme.soft)
        }
        .padding(.top, 6)
    }

    // MARK: - Bento grid

    private var blockGrid: some View {
        VStack(spacing: 10) {
            gridRow(.flow, .symptoms)
            gridRow(.mood, .body)
            gridRow(.intimacy, .test)
        }
        .animation(.spring(duration: 0.35), value: expandedBlock)
    }

    /// A row shows its two blocks side by side; if one is expanded it takes
    /// the full width and the other hides until collapse.
    @ViewBuilder
    private func gridRow(_ left: Block, _ right: Block) -> some View {
        if expandedBlock == left {
            expandedCard(left)
        } else if expandedBlock == right {
            expandedCard(right)
        } else {
            HStack(spacing: 10) {
                blockTile(left)
                blockTile(right)
            }
        }
    }

    private func blockTile(_ block: Block) -> some View {
        Button {
            expandedBlock = block
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: icon(for: block))
                        .imageScale(.small)
                        .foregroundStyle(iconTint(for: block))
                    Text(name(for: block))
                        .foregroundStyle(Theme.body)
                }
                .font(.footnote)
                Text(summary(for: block))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(tint(for: block), in: RoundedRectangle(cornerRadius: Theme.blockRadius))
        }
        .buttonStyle(.plain)
    }

    private func expandedCard(_ block: Block) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                expandedBlock = nil
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: icon(for: block))
                        .imageScale(.small)
                        .foregroundStyle(iconTint(for: block))
                    Text(name(for: block))
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Image(systemName: "chevron.up")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.soft)
                }
            }
            .buttonStyle(.plain)

            switch block {
            case .flow: flowContent
            case .symptoms: symptomsContent
            case .mood: moodContent
            case .body: bodyContent
            case .intimacy: intimacyContent
            case .test: testContent
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint(for: block), in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    // MARK: - Block metadata

    private func icon(for block: Block) -> String {
        switch block {
        case .flow: return "drop.fill"
        case .symptoms: return "heart.text.square.fill"
        case .mood: return "face.smiling.inverse"
        case .body: return "scalemass.fill"
        case .intimacy: return "heart.fill"
        case .test: return "testtube.2"
        }
    }

    private func iconTint(for block: Block) -> Color {
        switch block {
        case .flow: return Theme.primary
        case .symptoms: return Color(hex: 0xB58A6A)
        case .mood: return Color(hex: 0x9A7AA8)
        case .body: return Color(hex: 0xC08A5A)
        case .intimacy: return Color(hex: 0xD98A9E)
        case .test: return Color(hex: 0x8FAE94)
        }
    }

    private func name(for block: Block) -> String {
        switch block {
        case .flow: return "flow"
        case .symptoms: return "symptoms"
        case .mood: return "mood"
        case .body: return "body"
        case .intimacy: return "intimacy"
        case .test: return "test"
        }
    }

    private func tint(for block: Block) -> Color {
        switch block {
        case .flow: return Theme.rose
        case .symptoms: return Theme.sand
        case .mood: return Theme.lavender
        case .body: return Theme.peach
        case .intimacy: return Theme.pink
        case .test: return Theme.sage
        }
    }

    private func summary(for block: Block) -> String {
        switch block {
        case .flow:
            return flow?.displayName.lowercased() ?? "—"
        case .symptoms:
            return symptoms.isEmpty ? "—" : "\(symptoms.count) logged"
        case .mood:
            guard moodLogged else { return "—" }
            let names = moodLabels.sorted { $0.displayName < $1.displayName }.map { $0.displayName.lowercased() }
            return names.isEmpty ? "logged" : names.prefix(2).joined(separator: ", ")
        case .body:
            let weight = Double(weightText.replacingOccurrences(of: ",", with: "."))
                .map { String(format: "%.1f %@", $0, weightUnitLabel) }
            let temp = Double(bbtText.replacingOccurrences(of: ",", with: "."))
                .map { String(format: "%.1f°", $0) }
            let parts = [weight, temp].compactMap { $0 }
            return parts.isEmpty ? "—" : parts.joined(separator: " · ")
        case .intimacy:
            return sexualActivity?.displayName.lowercased() ?? "—"
        case .test:
            return ovulationTest?.displayName.lowercased() ?? "—"
        }
    }

    // MARK: - Expanded contents

    private var flowContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(FlowLevel.allCases) { level in
                    flowButton(level)
                }
            }
            Text("tap a selected level again to clear it")
                .font(.caption2)
                .foregroundStyle(Theme.soft)
        }
    }

    private var symptomsContent: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
            ForEach(Symptom.allCases) { symptom in
                symptomChip(symptom)
            }
        }
    }

    private var moodContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if moodLogged {
                HStack {
                    Text("unpleasant").font(.caption).foregroundStyle(Theme.soft)
                    Slider(value: $moodValence, in: -1...1, step: 0.1)
                    Text("pleasant").font(.caption).foregroundStyle(Theme.soft)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    ForEach(MoodLabel.allCases) { label in
                        moodChip(label)
                    }
                }
                Button("clear mood", role: .destructive) {
                    moodLogged = false
                    moodValence = 0
                    moodLabels = []
                }
                .font(.footnote)
            } else {
                Button {
                    moodLogged = true
                } label: {
                    Text("log how you're feeling")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("weight")
                    .font(.caption)
                    .foregroundStyle(Theme.soft)
                HStack(spacing: 14) {
                    weightStepButton(systemImage: "minus.circle.fill", delta: -0.1)
                    VStack(spacing: 2) {
                        TextField(weightPlaceholder, text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.system(.title2, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(weightUnitLabel)
                            .font(.caption)
                            .foregroundStyle(Theme.soft)
                    }
                    weightStepButton(systemImage: "plus.circle.fill", delta: 0.1)
                }
                if lastWeightKg != nil && weightText.isEmpty {
                    Text("starts from your last logged weight")
                        .font(.caption2)
                        .foregroundStyle(Theme.soft)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("basal temp")
                    .font(.caption)
                    .foregroundStyle(Theme.soft)
                HStack {
                    TextField("—", text: $bbtText)
                        .keyboardType(.decimalPad)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 90)
                    Text(bbtUnitLabel).font(.caption).foregroundStyle(Theme.soft)
                }
            }
        }
    }

    private var intimacyContent: some View {
        HStack(spacing: 8) {
            sexChip(nil, title: "none")
            sexChip(.protected, title: "protected")
            sexChip(.unprotected, title: "unprotected")
        }
    }

    private var testContent: some View {
        VStack(spacing: 6) {
            ForEach(OvulationTestResult.allCases) { result in
                Button {
                    ovulationTest = ovulationTest == result ? nil : result
                } label: {
                    HStack {
                        Text(result.displayName.lowercased())
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        if ovulationTest == result {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Theme.primary)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Theme.card.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Save bar

    private var saveBar: some View {
        VStack {
            Spacer()
            Button(action: save) {
                Text("save")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Theme.primary, in: RoundedRectangle(cornerRadius: 18))
            }
            .disabled(isSaving)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
    }

    // MARK: - Controls (restyled)

    private func flowButton(_ level: FlowLevel) -> some View {
        let isSelected = flow == level
        return Button {
            flow = isSelected ? nil : level
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .imageScale(level == .heavy ? .large : .medium)
                Text(level.displayName.lowercased())
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isSelected ? Theme.primary : Theme.card.opacity(0.7),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .foregroundStyle(isSelected ? .white : Theme.body)
        }
        .buttonStyle(.plain)
    }

    private func symptomChip(_ symptom: Symptom) -> some View {
        let isSelected = symptoms.contains(symptom)
        return Button {
            if isSelected {
                symptoms.remove(symptom)
            } else {
                symptoms.insert(symptom)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symptom.systemImage)
                    .imageScale(.small)
                Text(symptom.displayName.lowercased())
                    .font(.footnote)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                isSelected ? Theme.primary : Theme.card.opacity(0.7),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? .white : Theme.body)
        }
        .buttonStyle(.plain)
    }

    private func moodChip(_ label: MoodLabel) -> some View {
        let isSelected = moodLabels.contains(label)
        return Button {
            if isSelected { moodLabels.remove(label) } else { moodLabels.insert(label) }
        } label: {
            Text(label.displayName.lowercased())
                .font(.footnote)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Theme.primary : Theme.card.opacity(0.7), in: Capsule())
                .foregroundStyle(isSelected ? .white : Theme.body)
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
                .background(isSelected ? Theme.primary : Theme.card.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(isSelected ? .white : Theme.body)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Units & seeding

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

    /// Most recent weight logged before this sheet's day, for seeding entry.
    private var lastWeightKg: Double? {
        WeightMetrics.last(before: Calendar.current.startOfDay(for: date), in: store.weightByDay)?.kg
    }

    private var weightPlaceholder: String {
        lastWeightKg.map(inputFromKg) ?? "—"
    }

    private func weightStepButton(systemImage: String, delta: Double) -> some View {
        Button {
            let current = Double(weightText.replacingOccurrences(of: ",", with: "."))
                ?? lastWeightKg.map { usesImperialUnits ? $0 / Self.kgPerPound : $0 }
            guard let current else { return }
            weightText = String(format: "%.1f", max(0, current + delta))
        } label: {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(Theme.primary.opacity(0.85))
        }
        .buttonStyle(.plain)
        .disabled(weightText.isEmpty && lastWeightKg == nil)
    }

    // MARK: - Load & save

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
        sexualActivity = entry.sexualActivity == .unspecified ? nil : entry.sexualActivity
        ovulationTest = entry.ovulationTest
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
}

#Preview {
    LogView(date: Date())
        .environmentObject(CycleStore())
}
