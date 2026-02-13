import SwiftUI

struct OnboardingIntroView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var contentVisible = false
    @State private var buttonVisible = false
    private let primaryBlue = Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(primaryBlue.opacity(0.10))
                            .frame(width: 110, height: 110)

                        Image(systemName: "person.crop.circle.badge.calendar")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(primaryBlue)
                    }
                    Spacer()
                }

                Text("Welcome")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("Never forget\nwhat matters.")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(
                    "Contactly prepares you before meetings,\ntracks interactions,\nand reminds you to follow up."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .opacity(contentVisible ? 1 : 0.0)
            .offset(y: contentVisible ? 0 : 8)

            Spacer()

            Button("Get Started") {
                viewModel.continueFromIntro()
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
            .padding(.bottom, 8)
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
}
