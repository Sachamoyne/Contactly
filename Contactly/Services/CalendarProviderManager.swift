import Foundation
import Observation

@Observable
@MainActor
final class CalendarProviderManager {
    private let repository: SettingsRepository

    init(repository: SettingsRepository) {
        self.repository = repository
    }

    var activeProviders: Set<CalendarProvider> {
        Set(repository.settings.calendarProviders)
    }

    var hasConfiguredProviders: Bool {
        !repository.settings.calendarProviders.isEmpty
    }

    func updateSelection(_ providers: Set<CalendarProvider>) {
        let ordered = CalendarProvider.allCases.filter { providers.contains($0) }
        repository.setCalendarProviders(ordered)
    }

    func setProviderEnabled(_ provider: CalendarProvider, enabled: Bool) {
        var providers = activeProviders
        if enabled {
            providers.insert(provider)
        } else {
            providers.remove(provider)
        }
        updateSelection(providers)
    }

    func isEnabled(_ provider: CalendarProvider) -> Bool {
        activeProviders.contains(provider)
    }
}
