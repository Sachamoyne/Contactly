import Foundation
import UserNotifications

struct PostMeetingNotificationPayload {
    let contactId: UUID
    let contactName: String
    let eventId: String
}

final class PostMeetingNotificationService {
    private let center = UNUserNotificationCenter.current()
    private let identifierPrefix = "post-meeting-note-"

    func schedulePostMeetingNote(
        contactId: UUID,
        contactName: String,
        eventId: String,
        meetingEndDate: Date
    ) {
        let fireDate = meetingEndDate.addingTimeInterval(2 * 60)
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "How did the meeting with \(contactName) go?"
        content.body = "Add a note"
        content.sound = .default
        content.userInfo = [
            "type": "postMeetingNote",
            "contactId": contactId.uuidString,
            "contactName": contactName,
            "eventId": eventId
        ]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(identifierPrefix)\(eventId)-\(contactId.uuidString)",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    func payload(from userInfo: [AnyHashable: Any]) -> PostMeetingNotificationPayload? {
        guard let contactIdRaw = userInfo["contactId"] as? String,
              let contactId = UUID(uuidString: contactIdRaw),
              let contactName = userInfo["contactName"] as? String,
              let eventId = userInfo["eventId"] as? String
        else {
            return nil
        }

        return PostMeetingNotificationPayload(
            contactId: contactId,
            contactName: contactName,
            eventId: eventId
        )
    }
}
