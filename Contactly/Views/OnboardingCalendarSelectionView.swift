import SwiftUI

struct OnboardingCalendarSelectionView: View {
    var providerManager: CalendarProviderManager
    var appleService: CalendarService
    var googleService: GoogleCalendarService
    var onComplete: () -> Void

    @State private var useApple = false
    @State private var useGoogle = false
    @State private var useNoSync = false
    @State private var isSubmitting = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Choose your calendar provider")
                .font(.title2.weight(.bold))

            VStack(spacing: 12) {
                Toggle("Apple Calendar", isOn: $useApple)
                    .toggleStyle(.switch)
                Toggle("Google Calendar", isOn: $useGoogle)
                    .toggleStyle(.switch)
                Toggle("No Calendar Sync", isOn: $useNoSync)
                    .toggleStyle(.switch)
            }

            Spacer()

            Button {
                Task {
                    await continueTapped()
                }
            } label: {
                if isSubmitting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canContinue || isSubmitting)
        }
        .padding()
        .alert("Calendar Setup", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var canContinue: Bool {
        useApple || useGoogle || useNoSync
    }

    private func continueTapped() async {
        isSubmitting = true
        defer { isSubmitting = false }

        let providers: Set<CalendarProvider>
        if useNoSync {
            providers = []
        } else {
            var selected = Set<CalendarProvider>()
            if useApple {
                selected.insert(.apple)
            }
            if useGoogle {
                selected.insert(.google)
            }
            providers = selected
        }

        providerManager.updateSelection(providers)

        if providers.contains(.apple) {
            let granted = await appleService.requestFullAccessToEvents()
            if !granted {
                errorMessage = "Apple Calendar permission was denied. You can enable it in Settings later."
                showErrorAlert = true
            }
        }

        if providers.contains(.google) {
            do {
                try await googleService.signIn()
            } catch {
                providerManager.setProviderEnabled(.google, enabled: false)
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Google sign-in failed."
                showErrorAlert = true
                return
            }
        }

        onComplete()
    }
}
