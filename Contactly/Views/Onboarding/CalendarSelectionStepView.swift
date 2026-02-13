import SwiftUI

struct CalendarSelectionStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    private let primaryBlue = Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose your calendar provider")
                    .font(.system(size: 30, weight: .bold))

                Text("Contactly uses your calendar to detect upcoming interactions and show you context.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                calendarOptionRow(.apple)
                calendarOptionRow(.google)
                calendarOptionRow(.none)
            }

            Text("We only use your calendar to detect interactions. We never store your calendar data.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                Task {
                    await viewModel.continueFromCalendarSelection()
                }
            } label: {
                if viewModel.isProcessing {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(primaryBlue)
            )
            .shadow(color: primaryBlue.opacity(0.22), radius: 8, x: 0, y: 5)
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
                    .foregroundStyle(viewModel.selectedCalendarProvider == provider ? primaryBlue : .secondary)
            }
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}
