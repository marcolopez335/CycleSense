import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: CycleStore
    @State private var showingLog = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    cycleRing
                    if let phase = store.currentPhase {
                        phaseCard(phase)
                    }
                    if let window = store.prediction?.fertileWindow {
                        fertileCard(window)
                    }
                    todayCard
                }
                .padding()
            }
            .navigationTitle(Date.now.formatted(date: .abbreviated, time: .omitted))
            .toolbar {
                Button {
                    showingLog = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .accessibilityLabel("Log today")
            }
            .sheet(isPresented: $showingLog) {
                LogView(date: Date())
            }
            .refreshable { await store.refresh() }
        }
    }

    private var cycleRing: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 14)
            if let day = store.currentCycleDay,
               let length = store.prediction?.averageCycleLength, length > 0 {
                Circle()
                    .trim(from: 0, to: min(1, Double(day) / Double(length)))
                    .stroke(
                        AngularGradient(colors: [.pink, .red], center: .center),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 4) {
                if let day = store.currentCycleDay {
                    Text("Day \(day)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("No data yet")
                        .font(.title2.bold())
                    Text("Log your first period to start predictions")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
        }
        .frame(width: 220, height: 220)
        .padding(.top, 8)
    }

    private var statusText: String {
        guard let days = store.daysUntilNextPeriod else { return "" }
        if days > 1 { return "Period in \(days) days" }
        if days == 1 { return "Period tomorrow" }
        if days == 0 { return "Period expected today" }
        let late = -days
        return late == 1 ? "1 day late" : "\(late) days late"
    }

    private func phaseCard(_ phase: CyclePhase) -> some View {
        HStack(spacing: 14) {
            Image(systemName: phase.systemImage)
                .font(.title2)
                .foregroundStyle(.pink)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(phase.rawValue) phase")
                    .font(.headline)
                Text(phase.blurb)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func fertileCard(_ window: DateInterval) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.teal)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("Estimated fertile window")
                    .font(.headline)
                Text("\(window.start.formatted(.dateTime.month(.abbreviated).day())) – \(window.end.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

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
                Label(weightLine(kg), systemImage: "scalemass")
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

    private var usesImperialUnits: Bool {
        Locale.current.measurementSystem == .us
    }

    private func weightNumber(_ kg: Double) -> Double {
        usesImperialUnits ? kg / 0.45359237 : kg
    }

    private func formattedWeight(_ kg: Double) -> String {
        String(format: "%.1f %@", weightNumber(kg), usesImperialUnits ? "lb" : "kg")
    }

    /// "142.5 lb · 0.4 lb less than Fri" — neutral wording, no judgment.
    private func weightLine(_ kg: Double) -> String {
        let base = formattedWeight(kg)
        guard let previous = WeightMetrics.last(
            before: Calendar.current.startOfDay(for: Date()),
            in: store.weightByDay
        ) else { return base }
        let delta = weightNumber(kg) - weightNumber(previous.kg)
        let daysAgo = Calendar.current.dateComponents([.day], from: previous.date, to: Calendar.current.startOfDay(for: Date())).day ?? 0
        let when = daysAgo <= 6
            ? previous.date.formatted(.dateTime.weekday(.abbreviated))
            : previous.date.formatted(.dateTime.month(.abbreviated).day())
        if abs(delta) < 0.05 {
            return "\(base) · same as \(when)"
        }
        let deltaText = String(format: "%.1f %@", abs(delta), usesImperialUnits ? "lb" : "kg")
        return "\(base) · \(deltaText) \(delta < 0 ? "less" : "more") than \(when)"
    }

    private func formattedTemperature(_ celsius: Double) -> String {
        "Basal temp " + Measurement(value: celsius, unit: UnitTemperature.celsius)
            .formatted(.measurement(width: .abbreviated, usage: .person))
    }
}

#Preview {
    TodayView()
        .environmentObject(CycleStore())
}
