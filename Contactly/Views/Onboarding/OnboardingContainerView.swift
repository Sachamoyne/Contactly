import SwiftUI

struct OnboardingContainerView: View {
    @Bindable var viewModel: OnboardingViewModel
    var onFinished: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                progressHeader

                currentStepView
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding()
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

            Text(viewModel.currentStep.title)
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch viewModel.currentStep {
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
