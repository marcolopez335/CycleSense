import Charts
import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var store: CycleStore

    var body: some View {
        NavigationStack {
            Group {
                if store.cycles.isEmpty && store.weightByDay.isEmpty {
                    ContentUnavailableView(
                        "No cycles yet",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Log your first period from the Today or Calendar tab and your insights will appear here.")
                    )
                } else {
                    insightsList
                }
            }
            .navigationTitle("Insights")
        }
    }

    private var insightsList: some View {
        List {
            if !weightHistory.isEmpty {
                weightSection
            }

            Section("Averages") {
                LabeledContent("Average cycle length", value: lengthText(store.prediction?.averageCycleLength))
                LabeledContent("Average period length", value: lengthText(store.prediction?.averagePeriodLength))
                LabeledContent("Cycles tracked", value: "\(store.cycles.count)")
            }

            if let prediction = store.prediction {
                Section("Upcoming") {
                    LabeledContent(
                        "Next period",
                        value: prediction.nextPeriodStart.formatted(date: .abbreviated, time: .omitted)
                    )
                    if let window = prediction.fertileWindow {
                        LabeledContent(
                            "Fertile window",
                            value: "\(window.start.formatted(.dateTime.month(.abbreviated).day())) – \(window.end.formatted(.dateTime.month(.abbreviated).day()))"
                        )
                    }
                    if let ovulation = prediction.ovulationDate {
                        LabeledContent(
                            "Estimated ovulation",
                            value: ovulation.formatted(date: .abbreviated, time: .omitted)
                        )
                    }
                }
            }

            Section("History") {
                ForEach(store.cycles.reversed()) { cycle in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cycle.start.formatted(date: .abbreviated, time: .omitted))
                                .font(.body)
                            Text("Period: \(cycle.periodLength) \(cycle.periodLength == 1 ? "day" : "days")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let length = cycle.cycleLength {
                            Text("\(length)-day cycle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Ongoing")
                                .font(.subheadline)
                                .foregroundStyle(.pink)
                        }
                    }
                }
            }

            Section {
            } footer: {
                Text("Averages use your last \(CyclePredictor.historyWindow) cycles. Predictions are estimates for informational purposes only and are not medical advice or contraception.")
            }
        }
    }

    private func lengthText(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(value) days"
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
                    Text("Keep logging")
                        .font(.headline)
                    Text("Two or more entries and your trend appears here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                weightChart
                    .frame(height: 200)
                    .padding(.vertical, 6)
            }
        } header: {
            Text("Weight")
        } footer: {
            Text("Weight naturally shifts across your cycle — trends matter more than single days. Pink bands are logged period days.")
        }
    }

    private var weightChart: some View {
        Chart {
            ForEach(periodDaysInWindow, id: \.self) { day in
                RectangleMark(
                    xStart: .value("Start", day),
                    xEnd: .value("End", Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day)
                )
                .foregroundStyle(.pink.opacity(0.10))
            }
            ForEach(weightHistory, id: \.date) { entry in
                PointMark(
                    x: .value("Day", entry.date),
                    y: .value("Weight", displayUnit(entry.kg))
                )
                .foregroundStyle(.pink.opacity(0.55))
                .symbolSize(36)
            }
            ForEach(weightTrend, id: \.date) { entry in
                LineMark(
                    x: .value("Day", entry.date),
                    y: .value("Trend", displayUnit(entry.kg))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.pink)
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
