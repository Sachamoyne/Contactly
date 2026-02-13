import SwiftUI

struct OnboardingContainerView: View {
    @Bindable var viewModel: OnboardingViewModel
    var onFinished: () -> Void
    private let primaryBlue = Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255)

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 236 / 255, green: 245 / 255, blue: 1.0),
                        Color.white
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    progressHeader
                        .padding(.top, 8)

                    currentStepView
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.92))
                        )
                        .shadow(color: primaryBlue.opacity(0.10), radius: 18, x: 0, y: 8)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("Setup", isPresented: errorBinding) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.currentStep.progressText)
                .font(.caption)
                .foregroundStyle(.secondary)

            ProgressView(value: progressValue)
                .tint(primaryBlue)

            Text(viewModel.currentStep.title)
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch viewModel.currentStep {
        case .intro:
            OnboardingIntroView(viewModel: viewModel)
        case .userInfo:
            UserInfoStepView(viewModel: viewModel)
        case .calendarSelection:
            CalendarSelectionStepView(viewModel: viewModel)
        case .contactSync:
            ContactSyncStepView(viewModel: viewModel)
        case .completion:
            OnboardingCompletionView(viewModel: viewModel) {
                viewModel.finishOnboarding()
                onFinished()
            }
        }
    }

    private var progressValue: Double {
        switch viewModel.currentStep {
        case .intro:
            return 0
        case .userInfo:
            return 1.0 / 3.0
        case .calendarSelection:
            return 2.0 / 3.0
        case .contactSync, .completion:
            return 1.0
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.errorMessage = nil
                }
            }
        )
    }
}
