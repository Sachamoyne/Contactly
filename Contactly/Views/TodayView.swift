import SwiftUI

struct TodayView: View {
    var calendarService: CalendarService
    var notificationService: NotificationService
    var settingsRepository: SettingsRepository

    @State private var isLoading = true

    var body: some View {
        Group {
            if !calendarService.accessGranted {
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

        if !calendarService.accessGranted {
            let granted = await calendarService.requestAccess()
            guard granted else { return }
        }

        let events = calendarService.fetchTodayEvents()

        await notificationService.checkAuthorizationStatus()
        if !notificationService.isAuthorized {
            _ = await notificationService.requestAuthorization()
        }
        await notificationService.scheduleReminders(
            for: events,
            settings: settingsRepository.settings
        )
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
                Text(event.startDate, style: .time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("–")
                    .foregroundStyle(.secondary)
                Text(event.endDate, style: .time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !event.location.isEmpty {
                HStack {
                    Image(systemName: "location")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text(event.location)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
