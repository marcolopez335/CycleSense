import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: CycleStore
    @Environment(\.openURL) private var openURL
    @AppStorage(NotificationScheduler.periodEnabledKey) private var periodReminders = false
    @AppStorage(NotificationScheduler.fertileEnabledKey) private var fertileReminders = false
    @State private var notificationsDenied = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("health data", value: store.healthAvailable ? "available" : "unavailable")
                    Button("re-request health permissions") {
                        Task { await store.requestAccessAndRefresh() }
                    }
                    .disabled(!store.healthAvailable)
                    Button("open the health app") {
                        if let url = URL(string: "x-apple-health://") {
                            openURL(url)
                        }
                    }
                } header: {
                    sectionHeader("apple health")
                } footer: {
                    Text("iOS only shows the permission sheet once. to change access later, open the Health app → Sharing → Apps → CycleSense.")
                        .foregroundStyle(Theme.soft)
                }
                .listRowBackground(Theme.card)

                Section {
                    Toggle("period reminders", isOn: $periodReminders)
                    Toggle("fertile window reminder", isOn: $fertileReminders)
                    if notificationsDenied && (periodReminders || fertileReminders) {
                        Button("enable notifications in Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        }
                    }
                } header: {
                    sectionHeader("gentle reminders")
                } footer: {
                    Text("period reminders arrive 2 days before and on the estimated start day, at 9:00. the fertile reminder arrives when the estimated window opens.")
                        .foregroundStyle(Theme.soft)
                }
                .listRowBackground(Theme.card)

                Section {
                    Button("refresh data from health") {
                        Task { await store.refresh() }
                    }
                    .disabled(store.isRefreshing || !store.healthAvailable)
                } footer: {
                    Text("cyclesense stores nothing outside apple health. deleting the app never deletes your health data.")
                        .foregroundStyle(Theme.soft)
                }
                .listRowBackground(Theme.card)

                Section {
                    LabeledContent("version", value: "1.0")
                } header: {
                    sectionHeader("about")
                } footer: {
                    Text("CycleSense is not a medical device. Cycle, fertility, and ovulation predictions are estimates for informational purposes only — do not use them as contraception or medical advice. Talk to a healthcare provider about anything that concerns you.")
                        .foregroundStyle(Theme.soft)
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("settings")
            .task { notificationsDenied = await NotificationScheduler.permissionDenied() }
            .onChange(of: periodReminders) { _, _ in remindersChanged() }
            .onChange(of: fertileReminders) { _, _ in remindersChanged() }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(Theme.title(17))
            .foregroundStyle(Theme.ink)
            .textCase(nil)
    }

    private func remindersChanged() {
        Task {
            if periodReminders || fertileReminders {
                _ = await NotificationScheduler.requestPermission()
                notificationsDenied = await NotificationScheduler.permissionDenied()
            }
            await NotificationScheduler.reschedule(prediction: store.prediction)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(CycleStore())
}
