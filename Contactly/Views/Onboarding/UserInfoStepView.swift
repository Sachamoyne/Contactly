import SwiftUI

struct UserInfoStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    private let primaryBlue = Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Tell us who you are")
                .font(.system(size: 30, weight: .bold))

            VStack(spacing: 14) {
                TextField("First name", text: $viewModel.firstName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))

                TextField("Last name", text: $viewModel.lastName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))

                TextField("Email", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }

            Spacer()

            Button("Continue") {
                viewModel.continueFromUserInfo()
            }
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(primaryBlue)
            )
            .shadow(color: primaryBlue.opacity(0.22), radius: 8, x: 0, y: 5)
            .disabled(!viewModel.canContinueUserInfo)
            .opacity(viewModel.canContinueUserInfo ? 1 : 0.55)
        }
    }
}
