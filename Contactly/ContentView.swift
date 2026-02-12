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

    var body: some View {
        TabView {
            NavigationStack {
                TodayView(
                    meetingService: meetingService,
                    contactsViewModel: contactsViewModel,
                    notificationService: notificationService,
                    settingsRepository: settingsRepository
                )
            }
            .tabItem {
                Label("Today", systemImage: "calendar")
            }

            NavigationStack {
                ContactsListView(viewModel: contactsViewModel)
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
    }
}
