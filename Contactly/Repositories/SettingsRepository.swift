import Foundation

final class SettingsRepository {
    private let defaults: UserDefaults
    private let settingsKey = "com.contactly.reminderSettings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ReminderSettings {
        guard let data = defaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(ReminderSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func save(_ settings: ReminderSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: settingsKey)
    }
}
