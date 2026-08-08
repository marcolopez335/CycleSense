import SwiftUI

struct CycleCalendarView: View {
    @EnvironmentObject private var store: CycleStore
    @State private var displayedMonth = Calendar.current.startOfDay(for: Date())
    @State private var selectedDay: SelectedDay?

    private let calendar = Calendar.current

    private struct SelectedDay: Identifiable {
        let date: Date
        var id: Date { date }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 12) {
                    monthHeader
                    weekdayHeader
                    monthGrid
                    legend
                    Spacer(minLength: 0)
                }
                .padding(.horizontal)
            }
            .navigationTitle("calendar")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedDay) { day in
                LogView(date: day.date)
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(Theme.primary)
            }
            Spacer()
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()).lowercased())
                .font(Theme.title(20))
                .foregroundStyle(Theme.ink)
            Spacer()
            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.primary)
            }
        }
        .padding(.top, 8)
    }

    private func shiftMonth(by value: Int) {
        if let shifted = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = shifted
        }
    }

    private var weekdayHeader: some View {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        let ordered = Array(symbols[first...]) + Array(symbols[..<first])
        return HStack {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let cells = monthCells()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                if let date = cell {
                    DayCell(
                        dayNumber: calendar.component(.day, from: date),
                        mark: store.mark(for: date),
                        isToday: calendar.isDateInToday(date),
                        hasSymptoms: !store.symptoms(on: date).isEmpty
                    )
                    .onTapGesture { selectedDay = SelectedDay(date: date) }
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
    }

    /// Dates for the displayed month padded with leading nils so the first
    /// day lands on the correct weekday column.
    private func monthCells() -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth),
              let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }
        let firstDay = interval.start
        let leading = (calendar.component(.weekday, from: firstDay) - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayRange.count {
            cells.append(calendar.date(byAdding: .day, value: offset, to: firstDay))
        }
        return cells
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                LegendItem(color: Theme.primary, filled: true, label: "period")
                LegendItem(color: Theme.primary.opacity(0.25), filled: true, label: "predicted")
            }
            HStack(spacing: 16) {
                LegendItem(color: Color(hex: 0xC5D6C7), filled: true, label: "fertile")
                LegendItem(color: Color(hex: 0x8FAE94), filled: false, label: "ovulation")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}

private struct LegendItem: View {
    let color: Color
    let filled: Bool
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(filled ? color : .clear)
                .overlay(Circle().stroke(filled ? .clear : color, lineWidth: 1.5))
                .frame(width: 12, height: 12)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct DayCell: View {
    let dayNumber: Int
    let mark: CycleStore.DayMark?
    let isToday: Bool
    let hasSymptoms: Bool

    var body: some View {
        ZStack {
            background
            if isToday {
                Circle()
                    .stroke(Color.accentColor, lineWidth: 2)
            }
            VStack(spacing: 2) {
                Text("\(dayNumber)")
                    .font(.callout)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(textColor)
                if hasSymptoms {
                    Circle()
                        .fill(textColor.opacity(0.7))
                        .frame(width: 4, height: 4)
                }
            }
        }
        .frame(height: 44)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var background: some View {
        switch mark {
        case .period:
            Circle().fill(Theme.primary)
        case .predictedPeriod:
            Circle().fill(Theme.primary.opacity(0.18))
        case .fertile:
            Circle().fill(Color(hex: 0xC5D6C7).opacity(0.55))
        case .ovulation:
            Circle().stroke(Color(hex: 0x8FAE94), lineWidth: 1.5)
        case nil:
            EmptyView()
        }
    }

    private var textColor: Color {
        if case .period = mark { return .white }
        return Theme.ink
    }
}

#Preview {
    CycleCalendarView()
        .environmentObject(CycleStore())
}
