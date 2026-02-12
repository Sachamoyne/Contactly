import SwiftUI

struct ContentView: View {
    var calendarService: CalendarService
    var googleCalendarService: GoogleCalendarService
    var microsoftAuthService: MicrosoftAuthService
    var userProfileStore: UserProfileStore
    var calendarAggregatorService: CalendarAggregatorService
    var meetingService: MeetingService
    var notificationService: NotificationService
    var settingsRepository: SettingsRepository
    var contactsViewModel: ContactsViewModel
    var interactionRepository: InteractionRepository

    var body: some View {
        TabView {
            NavigationStack {
                TodayView(
                    meetingService: meetingService,
                    contactsViewModel: contactsViewModel,
                    notificationService: notificationService,
                    settingsRepository: settingsRepository,
                    interactionRepository: interactionRepository
                )
            }
            .tabItem {
                Label("Today", systemImage: "calendar")
            }

            NavigationStack {
                ContactsListView(
                    viewModel: contactsViewModel,
                    interactionRepository: interactionRepository
                )
            }
            .tabItem {
                Label("Contacts", systemImage: "person.2")
            }

            NavigationStack {
                SettingsView(
                    repository: settingsRepository,
                    contactsViewModel: contactsViewModel,
                    userProfileStore: userProfileStore,
                    googleCalendarService: googleCalendarService,
                    microsoftAuthService: microsoftAuthService,
                    appleCalendarService: calendarService,
                    calendarAggregatorService: calendarAggregatorService
                )
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
        .tint(AppTheme.accent)
    }
}
