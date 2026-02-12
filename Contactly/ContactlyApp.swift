import GoogleSignIn
import SwiftUI
import UIKit
import UserNotifications

final class MorningBriefingAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var launchedFromMorningBriefingNotification = false

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        if response.notification.request.identifier.hasPrefix("morning-briefing-") {
            Self.launchedFromMorningBriefingNotification = true
            NotificationCenter.default.post(name: .showMorningBriefingRequested, object: nil)
        }
    }
}

extension Notification.Name {
    static let showMorningBriefingRequested = Notification.Name("ShowMorningBriefingRequested")
}

@main
struct ContactlyApp: App {
    @UIApplicationDelegateAdaptor(MorningBriefingAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

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
    @State private var interactionRepository: InteractionRepository
    @State private var onboardingViewModel: OnboardingViewModel
    @State private var showMorningBriefing = false

    init() {
        let settingsRepository = SettingsRepository()
        let contactRepository = ContactRepository()
        let manualMeetingRepository = ManualMeetingRepository()
        let interactionRepository = InteractionRepository()
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
        _interactionRepository = State(initialValue: interactionRepository)
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
                        contactsViewModel: contactsViewModel,
                        interactionRepository: interactionRepository
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
            .onReceive(NotificationCenter.default.publisher(for: .showMorningBriefingRequested)) { _ in
                showMorningBriefing = true
            }
            .sheet(isPresented: $showMorningBriefing) {
                MorningBriefingView(
                    calendarService: calendarService,
                    contactsViewModel: contactsViewModel,
                    interactionRepository: interactionRepository
                )
            }
            .task {
                await notificationService.checkAuthorizationStatus()
                if !notificationService.isAuthorized {
                    _ = await notificationService.requestAuthorization()
                }
                await notificationService.scheduleMorningBriefing(calendarService: calendarService)

                if MorningBriefingAppDelegate.launchedFromMorningBriefingNotification {
                    showMorningBriefing = true
                    MorningBriefingAppDelegate.launchedFromMorningBriefingNotification = false
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    await notificationService.checkAuthorizationStatus()
                    if !notificationService.isAuthorized {
                        _ = await notificationService.requestAuthorization()
                    }
                    await notificationService.scheduleMorningBriefing(calendarService: calendarService)
                }
            }
        }
    }
}
