import Foundation

/// Small library of soft, non-medical daily tips per cycle phase.
/// Deterministic: the same cycle day always gets the same tip, rotating
/// through variants day to day. Pure and unit-tested.
enum CompanionTips {
    private static let tips: [CyclePhase: [String]] = [
        .menstrual: [
            "warmth helps — a heat pad or a warm drink can ease cramps.",
            "iron-rich food is your friend right now. and naps. naps count.",
            "gentle movement like stretching or a slow walk can ease the heaviness.",
        ],
        .follicular: [
            "energy usually climbs here — a good window for plans and workouts.",
            "skin often gets clearer this week. glow days.",
            "your body handles stress a bit better right now. big-task energy.",
        ],
        .ovulatory: [
            "you might feel extra social or confident around now — ride it.",
            "some people notice mild one-sided twinges — that can be ovulation.",
            "energy tends to peak here. good day to move your body.",
        ],
        .luteal: [
            "cravings and lower energy are normal here — be easy on yourself.",
            "sleep can get lighter this week. an earlier wind-down helps.",
            "bloating and tender skin happen to most people now. it passes.",
        ],
    ]

    static func tip(for phase: CyclePhase, cycleDay: Int) -> String {
        let variants = tips[phase] ?? []
        guard !variants.isEmpty else { return "" }
        let index = max(0, cycleDay - 1) % variants.count
        return variants[index]
    }
}
