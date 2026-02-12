import Foundation
import Observation

@Observable
final class SettingsRepository {
    private static let filename = "settings.json"

    var settings: ReminderSettings = .default

    init() {
        load()
    }

    func load() {
        guard PersistenceStore.exists(Self.filename) else { return }
        do {
            settings = try PersistenceStore.load(ReminderSettings.self, from: Self.filename)
        } catch {
            settings = .default
        }
    }

    func save() {
        try? PersistenceStore.save(settings, to: Self.filename)
    }

    func setDelay(_ minutes: Int) {
        settings.delayMinutes = minutes
        save()
    }
}
