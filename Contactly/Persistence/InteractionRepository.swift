import Foundation
import Observation

@Observable
final class InteractionRepository {
    private static let filename = "interactions.json"

    private(set) var interactions: [Interaction] = []

    init() {
        load()
    }

    func load() {
        guard PersistenceStore.exists(Self.filename) else { return }
        do {
            interactions = try PersistenceStore.load([Interaction].self, from: Self.filename)
        } catch {
            interactions = []
        }
    }

    func save() {
        try? PersistenceStore.save(interactions, to: Self.filename)
    }

    func add(_ interaction: Interaction) {
        interactions.append(interaction)
        save()
    }

    func delete(_ interaction: Interaction) {
        interactions.removeAll { $0.id == interaction.id }
        save()
    }

    func listByContact(contactId: UUID) -> [Interaction] {
        interactions
            .filter { $0.contactId == contactId }
            .sorted { $0.startDate > $1.startDate }
    }

    func listRecent(limit: Int) -> [Interaction] {
        interactions
            .sorted { $0.startDate > $1.startDate }
            .prefix(limit)
            .map { $0 }
    }

    func listForDateRange(from startDate: Date, to endDate: Date) -> [Interaction] {
        interactions
            .filter { $0.startDate >= startDate && $0.startDate <= endDate }
            .sorted { $0.startDate > $1.startDate }
    }

    func hasInteraction(eventId: String?, startDate: Date) -> Bool {
        if let eventId, !eventId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return interactions.contains {
                $0.eventId == eventId && Calendar.current.isDate($0.startDate, equalTo: startDate, toGranularity: .minute)
            }
        }

        return interactions.contains {
            Calendar.current.isDate($0.startDate, equalTo: startDate, toGranularity: .minute)
        }
    }
}

