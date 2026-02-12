import SwiftUI

struct SettingsView: View {
    @State private var settings: ReminderSettings
    private let repository: SettingsRepository

    init(repository: SettingsRepository = SettingsRepository()) {
        self.repository = repository
        self._settings = State(initialValue: repository.load())
    }

    var body: some View {
        Form {
            Section("Reminder Delay") {
                Picker("Notify me", selection: $settings.delayMinutes) {
                    Text("5 minutes before").tag(5)
                    Text("10 minutes before").tag(10)
                    Text("15 minutes before").tag(15)
                    Text("30 minutes before").tag(30)
                    Text("1 hour before").tag(60)
                }
            }

            Section("Quiet Hours") {
                Toggle("Enable Quiet Hours", isOn: $settings.quietHours.isEnabled)

                if settings.quietHours.isEnabled {
                    DatePicker(
                        "Start",
                        selection: quietHoursStartBinding,
                        displayedComponents: .hourAndMinute
                    )
                    DatePicker(
                        "End",
                        selection: quietHoursEndBinding,
                        displayedComponents: .hourAndMinute
                    )
                }
            }
        }
        .navigationTitle("Settings")
        .onChange(of: settings) {
            repository.save(settings)
        }
    }

    private var quietHoursStartBinding: Binding<Date> {
        Binding(
            get: {
                dateFrom(hour: settings.quietHours.startHour, minute: settings.quietHours.startMinute)
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                settings.quietHours.startHour = components.hour ?? 22
                settings.quietHours.startMinute = components.minute ?? 0
            }
        )
    }

    private var quietHoursEndBinding: Binding<Date> {
        Binding(
            get: {
                dateFrom(hour: settings.quietHours.endHour, minute: settings.quietHours.endMinute)
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                settings.quietHours.endHour = components.hour ?? 7
                settings.quietHours.endMinute = components.minute ?? 0
            }
        )
    }

    private func dateFrom(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}
