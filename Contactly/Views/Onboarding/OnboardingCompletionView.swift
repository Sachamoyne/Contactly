import SwiftUI

struct OnboardingCompletionView: View {
    @Bindable var viewModel: OnboardingViewModel
    var onDone: () -> Void
    @State private var contentVisible = false
    @State private var buttonVisible = false
    private let primaryBlue = Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(primaryBlue.opacity(0.12))
                            .frame(width: 84, height: 84)
                        Image(systemName: "checkmark")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(primaryBlue)
                    }
                    Spacer()
                }

                Text("You're ready.")
                    .font(.system(size: 32, weight: .bold))

                Text("You’ll now get context before interactions\nand smart follow-up reminders.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    summaryRow(label: "Calendar sync", value: viewModel.selectedCalendarProvider.displayName)
                    summaryRow(label: "Contact sync", value: viewModel.selectedContactSyncOption.displayName)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.78))
                )
            }
            .opacity(contentVisible ? 1 : 0.0)
            .offset(y: contentVisible ? 0 : 8)

            Spacer()

            Button("Start Using Contactly") {
                onDone()
            }
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(primaryBlue)
            )
            .shadow(color: primaryBlue.opacity(0.26), radius: 10, x: 0, y: 6)
            .opacity(buttonVisible ? 1 : 0.0)
            .offset(y: buttonVisible ? 0 : 14)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) {
                contentVisible = true
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.08)) {
                buttonVisible = true
            }
        }
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }
}
