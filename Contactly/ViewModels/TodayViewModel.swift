import Combine
import Foundation

@MainActor
final class TodayViewModel: ObservableObject {
    enum MeetingListItem: Identifiable {
        case synced(MeetingEvent)
        case manual(ManualMeeting)

        var id: String {
            switch self {
            case let .synced(meeting):
                return "synced-\(meeting.id)"
            case let .manual(meeting):
                return "manual-\(meeting.id.uuidString)"
            }
        }

        var startDate: Date {
            switch self {
            case let .synced(meeting):
                return meeting.startDate
            case let .manual(meeting):
                return meeting.date
            }
        }
    }

    @Published private(set) var meetingEvents: [MeetingEvent] = []
    @Published private(set) var manualMeetings: [ManualMeeting] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let meetingService: MeetingService

    init(meetingService: MeetingService) {
        self.meetingService = meetingService
    }

    var sortedMeetings: [MeetingListItem] {
        let syncedItems = meetingEvents.map(MeetingListItem.synced)
        let manualItems = manualMeetings.map(MeetingListItem.manual)
        return (syncedItems + manualItems).sorted { $0.startDate < $1.startDate }
    }

    func refresh(for date: Date = Date()) async {
        isLoading = true
        defer { isLoading = false }

        do {
            meetingEvents = try await meetingService.syncMeetingEvents(for: date)
            manualMeetings = meetingService.manualMeetings(for: date)
            errorMessage = nil
        } catch {
            manualMeetings = meetingService.manualMeetings(for: date)
            errorMessage = nil
            print("Today refresh sync error: \(error)")
        }
    }

    func createManualMeeting(contactID: UUID, date: Date, occasion: String, notes: String) async {
        meetingService.addManualMeeting(contactID: contactID, date: date, occasion: occasion, notes: notes)
        manualMeetings = meetingService.manualMeetings(for: date)
    }

    func updateManualMeeting(_ meeting: ManualMeeting) async {
        meetingService.updateManualMeeting(meeting)
        manualMeetings = meetingService.manualMeetings(for: meeting.date)
    }

    func deleteManualMeeting(_ meeting: ManualMeeting) async {
        let day = meeting.date
        meetingService.deleteManualMeeting(meeting)
        manualMeetings = meetingService.manualMeetings(for: day)
    }

    func contact(for manualMeeting: ManualMeeting) -> Contact? {
        meetingService.contact(for: manualMeeting)
    }
}
