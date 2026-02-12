import SwiftUI

struct SettingsView: View {
    @Bindable var repository: SettingsRepository

    var body: some View {
        Form {
            Section("Reminder Delay") {
                Picker("Notify me", selection: $repository.settings.delayMinutes) {
                    Text("5 minutes before").tag(5)
                    Text("10 minutes before").tag(10)
                    Text("15 minutes before").tag(15)
                    Text("30 minutes before").tag(30)
                    Text("1 hour before").tag(60)
                }
            }

            Section("Quiet Hours") {
                Toggle("Enable Quiet Hours", isOn: $repository.settings.quietHours.isEnabled)

                if repository.settings.quietHours.isEnabled {
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
        .onChange(of: repository.settings) {
            repository.save()
        }
    }

    private var quietHoursStartBinding: Binding<Date> {
        Binding(
            get: {
                dateFrom(hour: repository.settings.quietHours.startHour, minute: repository.settings.quietHours.startMinute)
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                repository.settings.quietHours.startHour = components.hour ?? 22
                repository.settings.quietHours.startMinute = components.minute ?? 0
            }
        )
    }

    private var quietHoursEndBinding: Binding<Date> {
        Binding(
            get: {
                dateFrom(hour: repository.settings.quietHours.endHour, minute: repository.settings.quietHours.endMinute)
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                repository.settings.quietHours.endHour = components.hour ?? 7
                repository.settings.quietHours.endMinute = components.minute ?? 0
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
