import SwiftUI

/// Sheet for logging (or editing) one day's flow and symptoms.
struct LogView: View {
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
                .foregroundStyle(.pink.opacity(0.85))
        }
        .buttonStyle(.plain)
        .disabled(weightText.isEmpty && lastWeightKg == nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 8) {
                        ForEach(FlowLevel.allCases) { level in
                            flowButton(level)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                } header: {
                    Text("Menstrual flow")
                } footer: {
                    Text("Tap a selected level again to clear it. Clearing removes entries created by CycleSense; entries from other apps can be deleted in the Health app.")
                }

                Section("Symptoms") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                        ForEach(Symptom.allCases) { symptom in
                            symptomChip(symptom)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                }

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
                    HStack(spacing: 14) {
                        weightStepButton(systemImage: "minus.circle.fill", delta: -0.1)
                        VStack(spacing: 2) {
                            TextField(weightPlaceholder, text: $weightText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .font(.system(.title2, design: .rounded, weight: .semibold))
                            Text(weightUnitLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        weightStepButton(systemImage: "plus.circle.fill", delta: 0.1)
                    }
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                } header: {
                    Text("Weight")
                } footer: {
                    if lastWeightKg != nil && weightText.isEmpty {
                        Text("Starts from your last logged weight.")
                    }
                }

                Section {
                    DisclosureGroup("Basal temperature", isExpanded: $bodyExpanded) {
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
            }
            .navigationTitle(date.formatted(date: .abbreviated, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaving)
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    private func flowButton(_ level: FlowLevel) -> some View {
        let isSelected = flow == level
        return Button {
            flow = isSelected ? nil : level
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .imageScale(level == .heavy ? .large : .medium)
                Text(level.displayName)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isSelected ? Color.red : Color(.systemGray5),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .foregroundStyle(isSelected ? .white : .primary)
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
                Text(symptom.displayName)
                    .font(.footnote)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.pink.opacity(0.85) : Color(.systemGray5),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

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
        if entry.bbtCelsius != nil { bodyExpanded = true }
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
}

#Preview {
    LogView(date: Date())
        .environmentObject(CycleStore())
}
