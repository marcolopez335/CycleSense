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
                    LabeledContent("Health data", value: store.healthAvailable ? "Available" : "Unavailable")
                    Button("Re-request Health permissions") {
                        Task { await store.requestAccessAndRefresh() }
                    }
                    .disabled(!store.healthAvailable)
                    Button("Open Health app") {
                        if let url = URL(string: "x-apple-health://") {
                            openURL(url)
                        }
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("iOS only shows the permission sheet once. To change access later, open the Health app and go to Sharing → Apps → CycleSense.")
                }

                Section {
                    Toggle("Period reminders", isOn: $periodReminders)
                    Toggle("Fertile window reminder", isOn: $fertileReminders)
                    if notificationsDenied && (periodReminders || fertileReminders) {
                        Button("Enable notifications in Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        }
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Period reminders arrive 2 days before and on the estimated start day, at 9:00. The fertile reminder arrives when the estimated window opens.")
                }

                Section {
                    Button("Refresh data from Health") {
                        Task { await store.refresh() }
                    }
                    .disabled(store.isRefreshing || !store.healthAvailable)
                } footer: {
                    Text("CycleSense stores nothing outside Apple Health. Deleting the app never deletes your Health data.")
                }

                Section {
                    LabeledContent("Version", value: "1.0")
                } header: {
                    Text("About")
                } footer: {
                    Text("CycleSense is not a medical device. Cycle, fertility, and ovulation predictions are estimates for informational purposes only — do not use them as contraception or medical advice. Talk to a healthcare provider about anything that concerns you.")
                }
            }
            .navigationTitle("Settings")
            .task { notificationsDenied = await NotificationScheduler.permissionDenied() }
            .onChange(of: periodReminders) { _, _ in remindersChanged() }
            .onChange(of: fertileReminders) { _, _ in remindersChanged() }
        }
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
