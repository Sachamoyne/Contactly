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

    func update(_ interaction: Interaction) {
        guard let index = interactions.firstIndex(where: { $0.id == interaction.id }) else { return }
        interactions[index] = interaction
        save()
    }

    func delete(_ interaction: Interaction) {
        interactions.removeAll { $0.id == interaction.id }
        save()
    }

    func listByContact(contactId: UUID) -> [Interaction] {
        getContactTimeline(contactId: contactId)
    }

    func getInteractions(for contactId: UUID) -> [Interaction] {
        getContactTimeline(contactId: contactId)
    }

    func getContactTimeline(contactId: UUID, limit: Int = 50) -> [Interaction] {
        interactions
            .filter { $0.contactId == contactId }
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map { $0 }
    }

    func listRecent(limit: Int) -> [Interaction] {
        interactions
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map { $0 }
    }

    func listForDateRange(from startDate: Date, to endDate: Date) -> [Interaction] {
        interactions
            .filter { $0.date >= startDate && $0.date <= endDate }
            .sorted { $0.date > $1.date }
    }

    func hasInteraction(eventId: String?, startDate: Date) -> Bool {
        hasInteraction(contactId: nil, eventId: eventId, date: startDate)
    }

    func hasInteraction(contactId: UUID? = nil, eventId: String?, date: Date) -> Bool {
        if let eventId, !eventId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return interactions.contains {
                contactMatches($0, contactId: contactId)
                    && $0.eventId == eventId
                    && Calendar.current.isDate($0.date, equalTo: date, toGranularity: .minute)
            }
        }

        return interactions.contains {
            contactMatches($0, contactId: contactId)
                && Calendar.current.isDate($0.date, equalTo: date, toGranularity: .minute)
        }
    }

    private func contactMatches(_ interaction: Interaction, contactId: UUID?) -> Bool {
        guard let contactId else { return true }
        return interaction.contactId == contactId
    }

    func getPendingFollowUps() -> [Interaction] {
        guard let endOfDay = Calendar.current.date(
            bySettingHour: 23,
            minute: 59,
            second: 59,
            of: Date()
        ) else {
            return []
        }

        return interactions
            .filter { interaction in
                guard let followUpDate = interaction.followUpDate else { return false }
                return followUpDate <= endOfDay
            }
            .sorted { (lhs, rhs) in
                guard let left = lhs.followUpDate, let right = rhs.followUpDate else {
                    return lhs.createdAt < rhs.createdAt
                }
                return left < right
            }
    }

    func getLastInteraction(for contactId: UUID) -> Interaction? {
        interactions
            .filter { $0.contactId == contactId }
            .max(by: { $0.date < $1.date })
    }

    func getRelationshipStatus(for contactId: UUID) -> (status: String, daysSince: Int?) {
        guard let lastInteraction = getLastInteraction(for: contactId) else {
            return ("No interactions yet", nil)
        }

        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: lastInteraction.date),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0

        if days <= 14 {
            return ("Strong", days)
        }

        if days <= 60 {
            return ("Medium", days)
        }

        return ("Weak", days)
    }
}
