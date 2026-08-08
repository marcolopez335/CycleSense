import Charts
import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var store: CycleStore

    var body: some View {
        NavigationStack {
            Group {
                if store.cycles.isEmpty && store.weightByDay.isEmpty {
                    ZStack {
                        Theme.background.ignoresSafeArea()
                        ContentUnavailableView(
                            "nothing here yet",
                            systemImage: "sparkles",
                            description: Text("log your first period from the Today or Calendar tab and your insights will bloom here")
                        )
                    }
                } else {
                    insightsList
                }
            }
            .navigationTitle("insights")
        }
    }

    private var patternInsights: [PatternInsight] {
        PatternInsights.insights(
            cycles: store.cycles,
            flowByDay: store.flowByDay,
            symptomsByDay: store.symptomsByDay,
            moodByDay: store.moodByDay
        )
    }

    private var insightsList: some View {
        List {
            patternsSection

            if !weightHistory.isEmpty {
                weightSection
            }

            Section {
                LabeledContent("average cycle length", value: lengthText(store.prediction?.averageCycleLength))
                LabeledContent("average period length", value: lengthText(store.prediction?.averagePeriodLength))
                LabeledContent("cycles tracked", value: "\(store.cycles.count)")
            } header: {
                sectionHeader("your rhythm")
            }
            .listRowBackground(Theme.card)

            if let prediction = store.prediction {
                Section {
                    LabeledContent(
                        "next period",
                        value: prediction.nextPeriodStart.formatted(date: .abbreviated, time: .omitted)
                    )
                    if let window = prediction.fertileWindow {
                        LabeledContent(
                            "fertile window",
                            value: "\(window.start.formatted(.dateTime.month(.abbreviated).day())) – \(window.end.formatted(.dateTime.month(.abbreviated).day()))"
                        )
                    }
                    if let ovulation = prediction.ovulationDate {
                        LabeledContent(
                            "estimated ovulation",
                            value: ovulation.formatted(date: .abbreviated, time: .omitted)
                        )
                    }
                } header: {
                    sectionHeader("coming up")
                }
                .listRowBackground(Theme.card)
            }

            Section {
                ForEach(store.cycles.reversed()) { cycle in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cycle.start.formatted(date: .abbreviated, time: .omitted))
                                .font(.body)
                                .foregroundStyle(Theme.ink)
                            Text("period: \(cycle.periodLength) \(cycle.periodLength == 1 ? "day" : "days")")
                                .font(.caption)
                                .foregroundStyle(Theme.soft)
                        }
                        Spacer()
                        if let length = cycle.cycleLength {
                            Text("\(length)-day cycle")
                                .font(.subheadline)
                                .foregroundStyle(Theme.body)
                        } else {
                            Text("ongoing")
                                .font(.subheadline)
                                .foregroundStyle(Theme.primary)
                        }
                    }
                }
            } header: {
                sectionHeader("your history")
            }
            .listRowBackground(Theme.card)

            Section {
            } footer: {
                Text("averages use your last \(CyclePredictor.historyWindow) cycles. predictions are estimates for informational purposes only — not medical advice or contraception.")
                    .foregroundStyle(Theme.soft)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(Theme.title(17))
            .foregroundStyle(Theme.ink)
            .textCase(nil)
    }

    private var patternsSection: some View {
        Section {
            let insights = patternInsights
            if insights.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("still learning you")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("log symptoms and moods across a couple of cycles and your patterns show up here.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.body)
                }
                .padding(.vertical, 4)
            } else {
                ForEach(insights, id: \.text) { insight in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: insight.symbol)
                            .imageScale(.small)
                            .foregroundStyle(Theme.primary)
                            .frame(width: 20)
                        Text(insight.text)
                            .font(.subheadline)
                            .foregroundStyle(Theme.body)
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            sectionHeader("your patterns")
        } footer: {
            if !patternInsights.isEmpty {
                Text("patterns come from your own logs across completed cycles — not medical advice.")
                    .foregroundStyle(Theme.soft)
            }
        }
        .listRowBackground(Theme.card)
    }

    private func lengthText(_ value: Int?) -> String {
        guard let value else { return "—" }
        return value == 1 ? "1 day" : "\(value) days"
    }

    // MARK: - Weight trend

    private static let chartDays = 90

    private var usesImperialUnits: Bool {
        Locale.current.measurementSystem == .us
    }

    private var weightUnitLabel: String { usesImperialUnits ? "lb" : "kg" }

    private func displayUnit(_ kg: Double) -> Double {
        usesImperialUnits ? kg / 0.45359237 : kg
    }

    private var chartWindowStart: Date {
        Calendar.current.date(byAdding: .day, value: -Self.chartDays, to: Calendar.current.startOfDay(for: Date()))
            ?? Date()
    }

    private var weightHistory: [WeightMetrics.Entry] {
        WeightMetrics.history(from: store.weightByDay).filter { $0.date >= chartWindowStart }
    }

    private var weightTrend: [WeightMetrics.Entry] {
        WeightMetrics.movingAverage(weightHistory, windowDays: 7)
    }

    /// Logged period days inside the chart window, shaded for cycle context.
    private var periodDaysInWindow: [Date] {
        store.flowByDay.keys.filter { $0 >= chartWindowStart }.sorted()
    }

    private var weightSection: some View {
        Section {
            if weightHistory.count < 2 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("keep logging")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("two or more entries and your trend appears here.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.body)
                }
                .padding(.vertical, 4)
            } else {
                weightChart
                    .frame(height: 200)
                    .padding(.vertical, 6)
            }
        } header: {
            sectionHeader("your weight")
        } footer: {
            Text("weight naturally shifts across your cycle — trends matter more than single days. pink bands are logged period days.")
                .foregroundStyle(Theme.soft)
        }
        .listRowBackground(Theme.card)
    }

    private var weightChart: some View {
        Chart {
            ForEach(periodDaysInWindow, id: \.self) { day in
                RectangleMark(
                    xStart: .value("Start", day),
                    xEnd: .value("End", Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day)
                )
                .foregroundStyle(Theme.primary.opacity(0.10))
            }
            ForEach(weightHistory, id: \.date) { entry in
                PointMark(
                    x: .value("Day", entry.date),
                    y: .value("Weight", displayUnit(entry.kg))
                )
                .foregroundStyle(Theme.primary.opacity(0.5))
                .symbolSize(36)
            }
            ForEach(weightTrend, id: \.date) { entry in
                LineMark(
                    x: .value("Day", entry.date),
                    y: .value("Trend", displayUnit(entry.kg))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Theme.primary)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(v, format: .number.precision(.fractionLength(0))) \(weightUnitLabel)")
                    }
                }
            }
        }
    }
}

#Preview {
    InsightsView()
        .environmentObject(CycleStore())
}
