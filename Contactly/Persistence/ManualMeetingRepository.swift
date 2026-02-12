import Foundation
import Observation

@Observable
final class ManualMeetingRepository {
    private static let filename = "manual_meetings.json"

    private(set) var meetings: [ManualMeeting] = []

    init() {
        load()
    }

    func load() {
        guard PersistenceStore.exists(Self.filename) else { return }
        do {
            meetings = try PersistenceStore.load([ManualMeeting].self, from: Self.filename)
        } catch {
            meetings = []
        }
    }

    func save() {
        try? PersistenceStore.save(meetings, to: Self.filename)
    }

    func add(_ meeting: ManualMeeting) {
        meetings.append(meeting)
        save()
    }

    func update(_ meeting: ManualMeeting) {
        guard let index = meetings.firstIndex(where: { $0.id == meeting.id }) else { return }
        meetings[index] = meeting
        save()
    }

    func delete(_ meeting: ManualMeeting) {
        meetings.removeAll { $0.id == meeting.id }
        save()
    }

    func meetings(on date: Date) -> [ManualMeeting] {
        meetings.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }
}
