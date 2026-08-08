import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: CycleStore
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var isRequesting = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "camera.macro")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.primary)
                Text("welcome to\ncyclesense")
                    .font(Theme.title(34))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text("your cycle, understood. softly.")
                    .foregroundStyle(Theme.soft)

                VStack(alignment: .leading, spacing: 20) {
                    OnboardingRow(
                        icon: "drop.fill",
                        tint: Theme.primary,
                        title: "log your days",
                        detail: "flow, feelings, body — a few taps and done."
                    )
                    OnboardingRow(
                        icon: "calendar",
                        tint: Color(hex: 0xD98A9E),
                        title: "see what's ahead",
                        detail: "gentle estimates for your next period, fertile window, and ovulation."
                    )
                    OnboardingRow(
                        icon: "heart.text.square.fill",
                        tint: Color(hex: 0x8FAE94),
                        title: "synced with apple health",
                        detail: "everything lives in Health, under your control. nothing leaves your phone."
                    )
                }
                .padding(.vertical, 24)

                Spacer()

                if !store.healthAvailable {
                    Text("health data is not available on this device.")
                        .font(.footnote)
                        .foregroundStyle(Theme.soft)
                }

                Button(action: connect) {
                    Text(store.healthAvailable ? "connect apple health" : "continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.primary, in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .disabled(isRequesting)

                Text("CycleSense is not a medical device. Predictions are estimates — do not rely on them for contraception.")
                    .font(.caption2)
                    .foregroundStyle(Theme.soft)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
    }

    private func connect() {
        isRequesting = true
        Task {
            await store.requestAccessAndRefresh()
            isRequesting = false
            hasCompletedOnboarding = true
        }
    }
}

private struct OnboardingRow: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.body)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(CycleStore())
}
