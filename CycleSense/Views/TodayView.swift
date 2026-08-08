import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: CycleStore
    @State private var showingLog = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        HStack { Spacer(); cycleRing; Spacer() }
                        if let phase = store.currentPhase {
                            phaseCard(phase)
                        }
                        if let window = store.prediction?.fertileWindow {
                            fertileCard(window)
                        }
                        todayCard
                    }
                    .padding(16)
                }
            }
            .toolbar {
                Button {
                    showingLog = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.primary)
                }
                .accessibilityLabel("log today")
            }
            .sheet(isPresented: $showingLog) {
                LogView(date: Date())
            }
            .refreshable { await store.refresh() }
        }
    }

    private var greeting: String {
        if store.currentPhase == .menstrual { return "hey, it's period day" }
        if let day = store.currentCycleDay { return "day \(day) — hi you" }
        return "welcome in"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(greeting)
                .font(Theme.title())
                .foregroundStyle(Theme.ink)
            Text(Date.now.formatted(date: .complete, time: .omitted).lowercased())
                .font(.footnote)
                .foregroundStyle(Theme.soft)
        }
    }

    private var cycleRing: some View {
        ZStack {
            Circle()
                .stroke(Theme.pink, lineWidth: 14)
            if let day = store.currentCycleDay,
               let length = store.prediction?.averageCycleLength, length > 0 {
                Circle()
                    .trim(from: 0, to: min(1, Double(day) / Double(length)))
                    .stroke(
                        AngularGradient(
                            colors: [Theme.primary.opacity(0.75), Theme.primary],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 4) {
                if let day = store.currentCycleDay {
                    Text("day \(day)")
                        .font(.system(size: 38, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.ink)
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(Theme.soft)
                        .multilineTextAlignment(.center)
                } else {
                    Text("no data yet")
                        .font(Theme.title(22))
                        .foregroundStyle(Theme.ink)
                    Text("log your first period and predictions start here")
                        .font(.footnote)
                        .foregroundStyle(Theme.soft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
        }
        .frame(width: 210, height: 210)
        .padding(.top, 2)
    }

    private var statusText: String {
        guard let days = store.daysUntilNextPeriod else { return "" }
        if days > 1 { return "period in \(days) days" }
        if days == 1 { return "period tomorrow" }
        if days == 0 { return "period expected today" }
        let late = -days
        return late == 1 ? "1 day late" : "\(late) days late"
    }

    private func phaseCard(_ phase: CyclePhase) -> some View {
        HStack(spacing: 14) {
            Image(systemName: phase.systemImage)
                .font(.title2)
                .foregroundStyle(Theme.primary)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(phase.rawValue.lowercased()) phase")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text(phase.blurb)
                    .font(.footnote)
                    .foregroundStyle(Theme.body)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .cozyCard()
    }

    private func fertileCard(_ window: DateInterval) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(Color(hex: 0x8FAE94))
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("estimated fertile window")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("\(window.start.formatted(.dateTime.month(.abbreviated).day())) – \(window.end.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.footnote)
                    .foregroundStyle(Theme.body)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .cozyCard()
    }

    private var todayCard: some View {
        let entry = store.dayLogEntry(on: Date())
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("today's log")
                    .font(Theme.title(19))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button("log") { showingLog = true }
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.primary)
            }
            if let flow = entry.flow {
                logLine("drop.fill", Theme.primary, "\(flow.displayName.lowercased()) flow")
            }
            if !entry.symptoms.isEmpty {
                logLine("heart.text.square.fill", Color(hex: 0xB58A6A), entry.symptoms.sorted { $0.displayName < $1.displayName }
                    .map { $0.displayName.lowercased() }
                    .joined(separator: ", "))
            }
            if let mood = entry.mood {
                logLine("face.smiling.inverse", Color(hex: 0x9A7AA8), moodSummary(mood))
            }
            if let sex = entry.sexualActivity {
                logLine("heart.fill", Color(hex: 0xD98A9E), "intimacy (\(sex.displayName.lowercased()))")
            }
            if let kg = entry.weightKg {
                logLine("scalemass.fill", Color(hex: 0xC08A5A), weightLine(kg))
            }
            if let celsius = entry.bbtCelsius {
                logLine("medical.thermometer.fill", Color(hex: 0xC08A5A), formattedTemperature(celsius))
            }
            if let test = entry.ovulationTest {
                logLine("testtube.2", Color(hex: 0x8FAE94), "ovulation test: \(test.displayName.lowercased())")
            }
            if entryIsEmpty(entry) {
                Text("nothing logged yet — tap log when you're ready")
                    .font(.subheadline)
                    .foregroundStyle(Theme.soft)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cozyCard()
    }

    private func logLine(_ icon: String, _ tint: Color, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .imageScale(.small)
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.body)
        }
    }

    private func entryIsEmpty(_ entry: DayLogEntry) -> Bool {
        entry.flow == nil && entry.symptoms.isEmpty && entry.mood == nil
            && entry.weightKg == nil && entry.bbtCelsius == nil
            && entry.sexualActivity == nil && entry.ovulationTest == nil
    }

    private func moodSummary(_ mood: MoodEntry) -> String {
        let tone: String
        switch mood.valence {
        case ..<(-0.33): tone = "unpleasant"
        case 0.33...: tone = "pleasant"
        default: tone = "neutral"
        }
        let labels = mood.labels.sorted { $0.displayName < $1.displayName }
            .map { $0.displayName.lowercased() }
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

    /// "142.5 lb · 0.5 lb less than sun" — neutral wording, no judgment.
    private func weightLine(_ kg: Double) -> String {
        let base = formattedWeight(kg)
        guard let previous = WeightMetrics.last(
            before: Calendar.current.startOfDay(for: Date()),
            in: store.weightByDay
        ) else { return base }
        let delta = weightNumber(kg) - weightNumber(previous.kg)
        let daysAgo = Calendar.current.dateComponents([.day], from: previous.date, to: Calendar.current.startOfDay(for: Date())).day ?? 0
        let when = (daysAgo <= 6
            ? previous.date.formatted(.dateTime.weekday(.abbreviated))
            : previous.date.formatted(.dateTime.month(.abbreviated).day())).lowercased()
        if abs(delta) < 0.05 {
            return "\(base) · same as \(when)"
        }
        let deltaText = String(format: "%.1f %@", abs(delta), usesImperialUnits ? "lb" : "kg")
        return "\(base) · \(deltaText) \(delta < 0 ? "less" : "more") than \(when)"
    }

    private func formattedTemperature(_ celsius: Double) -> String {
        let value = usesImperialUnits ? celsius * 9 / 5 + 32 : celsius
        return String(format: "basal temp %.1f%@", value, usesImperialUnits ? "°F" : "°C")
    }
}

#Preview {
    TodayView()
        .environmentObject(CycleStore())
}
