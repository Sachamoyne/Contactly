import SwiftUI

struct OnboardingCompletionView: View {
    @Bindable var viewModel: OnboardingViewModel
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("You're all set")
                .font(.title2.weight(.bold))

            Text("Contactly is ready. Your sync preferences are saved and can be changed anytime from Settings.")
                .foregroundStyle(.secondary)

            Spacer()

            Button("Start Using Contactly") {
                onDone()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
