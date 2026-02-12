import Foundation
import Observation

@Observable
final class UserProfileStore {
    private static let filename = "user_profile.json"
    private static let onboardingKey = "hasCompletedOnboarding"

    var profile: UserProfile = .empty
    var hasCompletedOnboarding: Bool = false

    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingKey)
        load()
    }

    func load() {
        guard PersistenceStore.exists(Self.filename) else { return }
        do {
            profile = try PersistenceStore.load(UserProfile.self, from: Self.filename)
        } catch {
            profile = .empty
        }
    }

    func save() {
        try? PersistenceStore.save(profile, to: Self.filename)
    }

    func updateProfile(_ updatedProfile: UserProfile) {
        profile = updatedProfile
        save()
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: Self.onboardingKey)
    }
}
