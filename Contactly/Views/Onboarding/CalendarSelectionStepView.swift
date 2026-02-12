import SwiftUI

struct CalendarSelectionStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Choose your calendar source")
                .font(.headline)

            VStack(spacing: 12) {
                calendarOptionRow(.apple)
                calendarOptionRow(.google)
                calendarOptionRow(.outlook)
                calendarOptionRow(.none)
            }

            Spacer()

            Button {
                Task {
                    await viewModel.continueFromCalendarSelection()
                }
            } label: {
                if viewModel.isProcessing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isProcessing)
        }
    }

    private func calendarOptionRow(_ provider: CalendarProvider) -> some View {
        Button {
            viewModel.selectedCalendarProvider = provider
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.displayName)
                        .foregroundStyle(.primary)
                }
                Spacer()
                Image(systemName: viewModel.selectedCalendarProvider == provider ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(viewModel.selectedCalendarProvider == provider ? .blue : .secondary)
            }
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
