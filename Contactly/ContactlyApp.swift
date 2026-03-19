import GoogleSignIn
import SwiftUI
import UIKit
import UserNotifications

final class MorningBriefingAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var launchedFromMorningBriefingNotification = false
    static var launchedFromPostMeetingNoteNotification: PostMeetingNotificationPayload?
    private let postMeetingNotificationService = PostMeetingNotificationService()

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
            return
        }

        let userInfo = response.notification.request.content.userInfo
        if let payload = postMeetingNotificationService.payload(from: userInfo) {
            Self.launchedFromPostMeetingNoteNotification = payload
            NotificationCenter.default.post(name: .showPostMeetingNoteRequested, object: payload)
        }
    }
}

extension Notification.Name {
    static let showMorningBriefingRequested = Notification.Name("ShowMorningBriefingRequested")
    static let showPostMeetingNoteRequested = Notification.Name("ShowPostMeetingNoteRequested")
}

@main
struct ContactlyApp: App {
    @UIApplicationDelegateAdaptor(MorningBriefingAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @State private var calendarService: CalendarService
    @State private var googleCalendarService: GoogleCalendarService
    @State private var userProfileStore: UserProfileStore
    @State private var calendarAggregatorService: CalendarAggregatorService
    @State private var meetingService: MeetingService
    @State private var notificationService: NotificationService
    @State private var settingsRepository: SettingsRepository
    @State private var contactsViewModel: ContactsViewModel
    @State private var interactionRepository: InteractionRepository
    @State private var showMorningBriefing = false
    @State private var quickNoteContact: Contact?

    init() {
        let notificationService = NotificationService.shared
        let settingsRepository = SettingsRepository()
        let contactRepository = ContactRepository(notificationService: notificationService)
        let manualMeetingRepository = ManualMeetingRepository()
        let interactionRepository = InteractionRepository()
        let contactsViewModel = ContactsViewModel(repository: contactRepository)
        let userProfileStore = UserProfileStore()
        let calendarService = CalendarService()
        let googleCalendarService = GoogleCalendarService()
        let calendarAggregatorService = CalendarAggregatorService(
            appleService: calendarService,
            googleService: googleCalendarService,
            userProfileStore: userProfileStore
        )
        let meetingService = MeetingService(
            calendarService: calendarService,
            googleCalendarService: googleCalendarService,
            userProfileStore: userProfileStore,
            settingsRepository: settingsRepository,
            contactRepository: contactRepository,
            manualMeetingRepository: manualMeetingRepository,
            interactionRepository: interactionRepository,
            postMeetingNotificationService: PostMeetingNotificationService()
        )
        _calendarService = State(initialValue: calendarService)
        _googleCalendarService = State(initialValue: googleCalendarService)
        _userProfileStore = State(initialValue: userProfileStore)
        _calendarAggregatorService = State(initialValue: calendarAggregatorService)
        _meetingService = State(initialValue: meetingService)
        _notificationService = State(initialValue: notificationService)
        _settingsRepository = State(initialValue: settingsRepository)
        _contactsViewModel = State(initialValue: contactsViewModel)
        _interactionRepository = State(initialValue: interactionRepository)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if userProfileStore.hasCompletedOnboarding {
                    RootTabView(
                        calendarService: calendarService,
                        googleCalendarService: googleCalendarService,
                        userProfileStore: userProfileStore,
                        calendarAggregatorService: calendarAggregatorService,
                        meetingService: meetingService,
                        notificationService: notificationService,
                        settingsRepository: settingsRepository,
                        contactsViewModel: contactsViewModel,
                        interactionRepository: interactionRepository
                    )
                } else {
                    OnboardingView(
                        contactRepository: contactsViewModel.repository,
                        userProfileStore: userProfileStore
                    )
                }
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .onReceive(NotificationCenter.default.publisher(for: .showMorningBriefingRequested)) { _ in
                showMorningBriefing = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .showPostMeetingNoteRequested)) { notification in
                guard let payload = notification.object as? PostMeetingNotificationPayload else { return }
                openQuickNote(for: payload)
            }
            .sheet(isPresented: $showMorningBriefing) {
                MorningBriefingView(
                    calendarService: calendarService,
                    contactsViewModel: contactsViewModel,
                    interactionRepository: interactionRepository
                )
            }
            .sheet(item: $quickNoteContact) { contact in
                AddInteractionView(
                    contact: contact,
                    interactionRepository: interactionRepository,
                    preferredType: .note
                )
            }
            .task {
                await notificationService.checkAuthorizationStatus()
                if !notificationService.isAuthorized {
                    _ = await notificationService.requestAuthorization()
                }
                notificationService.syncBirthdayNotifications(for: contactsViewModel.repository.contacts)
                await notificationService.scheduleMorningBriefing(calendarService: calendarService)

                if MorningBriefingAppDelegate.launchedFromMorningBriefingNotification {
                    showMorningBriefing = true
                    MorningBriefingAppDelegate.launchedFromMorningBriefingNotification = false
                }

                if let payload = MorningBriefingAppDelegate.launchedFromPostMeetingNoteNotification {
                    openQuickNote(for: payload)
                    MorningBriefingAppDelegate.launchedFromPostMeetingNoteNotification = nil
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    await notificationService.checkAuthorizationStatus()
                    if !notificationService.isAuthorized {
                        _ = await notificationService.requestAuthorization()
                    }
                    notificationService.syncBirthdayNotifications(for: contactsViewModel.repository.contacts)
                    await notificationService.scheduleMorningBriefing(calendarService: calendarService)
                }
            }
        }
    }

    private func openQuickNote(for payload: PostMeetingNotificationPayload) {
        guard let contact = contactsViewModel.repository.contacts.first(where: { $0.id == payload.contactId }) else {
            return
        }
        quickNoteContact = contact
    }
}
