import SwiftUI

struct ContentView: View {
    @State private var calendarService = CalendarService()
    @State private var notificationService = NotificationService()
    @State private var settingsRepository = SettingsRepository()
    @State private var contactsViewModel = ContactsViewModel(repository: ContactRepository())

    var body: some View {
        TabView {
            NavigationStack {
                TodayView(
                    calendarService: calendarService,
                    notificationService: notificationService,
                    settingsRepository: settingsRepository
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink {
                            SettingsView(repository: settingsRepository)
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
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
        }
    }
}
