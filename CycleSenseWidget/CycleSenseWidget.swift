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
                    Image(systemName: "camera.macro")
                        .font(.title3)
                        .foregroundStyle(Theme.primary)
                    Text("open cyclesense to start tracking")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.soft)
                }
            }
        }
        .containerBackground(for: .widget) { Theme.background }
    }

    private func content(snapshot: WidgetSnapshot, cycleDay: Int) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text("day \(cycleDay)")
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let days = daysUntilNextPeriod {
                    Text(periodText(days))
                        .font(.caption2)
                        .foregroundStyle(Theme.soft)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            if family == .systemMedium {
                VStack(alignment: .leading, spacing: 6) {
                    if let phase = snapshot.phase {
                        Label("\(phase.lowercased()) phase", systemImage: "circle.hexagongrid.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.primary)
                    }
                    if let start = snapshot.fertileStart, let end = snapshot.fertileEnd {
                        Label(
                            "fertile \(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))",
                            systemImage: "sparkles"
                        )
                        .font(.caption)
                        .foregroundStyle(Color(hex: 0x8FAE94))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func periodText(_ days: Int) -> String {
        if days > 1 { return "period in \(days) days" }
        if days == 1 { return "period tomorrow" }
        if days == 0 { return "period expected today" }
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
