import SwiftUI

struct TodayView: View {
    @ObservedObject var calendarService: CalendarService
    @ObservedObject var notificationService: NotificationService

    @State private var isLoading = true

    var body: some View {
        Group {
            if !calendarService.hasAccess {
                permissionDeniedView
            } else if isLoading {
                ProgressView("Loading events...")
            } else if calendarService.events.isEmpty {
                emptyStateView
            } else {
                eventListView
            }
        }
        .navigationTitle("Today")
        .task {
            await loadEvents()
        }
    }

    private var permissionDeniedView: some View {
        ContentUnavailableView {
            Label("Calendar Access Required", systemImage: "calendar.badge.exclamationmark")
        } description: {
            Text("Contactly needs access to your calendar to show today's events.")
        } actions: {
            Button("Grant Access") {
                Task {
                    let granted = await calendarService.requestAccess()
                    if granted {
                        await loadEvents()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Events Today",
            systemImage: "calendar",
            description: Text("You have no upcoming events in the next 24 hours.")
        )
    }

    private var eventListView: some View {
        List(calendarService.events) { event in
            EventRow(event: event)
        }
    }

    private func loadEvents() async {
        isLoading = true
        defer { isLoading = false }

        if !calendarService.hasAccess {
            let granted = await calendarService.requestAccess()
            guard granted else { return }
        }

        let events = await calendarService.fetchNext24HoursEvents()

        // Auto-schedule reminders when events load
        await notificationService.checkAuthorizationStatus()
        if !notificationService.isAuthorized {
            _ = await notificationService.requestAuthorization()
        }
        await notificationService.scheduleReminders(for: events)
    }
}

private struct EventRow: View {
    let event: CalendarEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title)
                .font(.headline)

            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                if event.isAllDay {
                    Text("All Day")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(event.startDate, style: .time)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("–")
                        .foregroundStyle(.secondary)
                    Text(event.endDate, style: .time)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let location = event.location, !location.isEmpty {
                HStack {
                    Image(systemName: "location")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text(location)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(event.calendarName)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
