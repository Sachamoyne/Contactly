import GoogleSignIn
import SwiftUI

@main
struct ContactlyApp: App {
    @State private var calendarService: CalendarService
    @State private var googleCalendarService: GoogleCalendarService
    @State private var microsoftAuthService: MicrosoftAuthService
    @State private var outlookCalendarService: OutlookCalendarService
    @State private var userProfileStore: UserProfileStore
    @State private var calendarAggregatorService: CalendarAggregatorService
    @State private var meetingService: MeetingService
    @State private var notificationService: NotificationService
    @State private var settingsRepository: SettingsRepository
    @State private var contactsViewModel: ContactsViewModel
    @State private var onboardingViewModel: OnboardingViewModel

    init() {
        let settingsRepository = SettingsRepository()
        let contactRepository = ContactRepository()
        let manualMeetingRepository = ManualMeetingRepository()
        let contactsViewModel = ContactsViewModel(repository: contactRepository)
        let userProfileStore = UserProfileStore()
        let calendarService = CalendarService()
        let googleCalendarService = GoogleCalendarService()
        let microsoftAuthService = MicrosoftAuthService()
        let outlookCalendarService = OutlookCalendarService(authService: microsoftAuthService)
        let contactImportService = ContactImportService()
        let calendarAggregatorService = CalendarAggregatorService(
            appleService: calendarService,
            googleService: googleCalendarService,
            outlookService: outlookCalendarService,
            userProfileStore: userProfileStore
        )
        let meetingService = MeetingService(
            calendarService: calendarService,
            googleCalendarService: googleCalendarService,
            outlookCalendarService: outlookCalendarService,
            userProfileStore: userProfileStore,
            settingsRepository: settingsRepository,
            contactRepository: contactRepository,
            manualMeetingRepository: manualMeetingRepository
        )
        let onboardingViewModel = OnboardingViewModel(
            userProfileStore: userProfileStore,
            settingsRepository: settingsRepository,
            calendarService: calendarService,
            googleCalendarService: googleCalendarService,
            microsoftAuthService: microsoftAuthService,
            contactImportService: contactImportService,
            contactRepository: contactRepository
        )

        _calendarService = State(initialValue: calendarService)
        _googleCalendarService = State(initialValue: googleCalendarService)
        _microsoftAuthService = State(initialValue: microsoftAuthService)
        _outlookCalendarService = State(initialValue: outlookCalendarService)
        _userProfileStore = State(initialValue: userProfileStore)
        _calendarAggregatorService = State(initialValue: calendarAggregatorService)
        _meetingService = State(initialValue: meetingService)
        _notificationService = State(initialValue: NotificationService())
        _settingsRepository = State(initialValue: settingsRepository)
        _contactsViewModel = State(initialValue: contactsViewModel)
        _onboardingViewModel = State(initialValue: onboardingViewModel)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if userProfileStore.hasCompletedOnboarding {
                    ContentView(
                        calendarService: calendarService,
                        googleCalendarService: googleCalendarService,
                        microsoftAuthService: microsoftAuthService,
                        userProfileStore: userProfileStore,
                        calendarAggregatorService: calendarAggregatorService,
                        meetingService: meetingService,
                        notificationService: notificationService,
                        settingsRepository: settingsRepository,
                        contactsViewModel: contactsViewModel
                    )
                } else {
                    OnboardingContainerView(viewModel: onboardingViewModel) {}
                }
            }
            .onOpenURL { url in
                if microsoftAuthService.handleRedirectURL(url) {
                    return
                }
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
