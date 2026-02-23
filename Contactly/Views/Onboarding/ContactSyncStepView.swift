import Contacts
import SwiftUI
import UIKit

struct ContactSyncStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    @State private var showingPicker = false
    @State private var showingPermissionAlert = false
    private let primaryBlue = Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("See context instantly")
                    .font(.system(size: 30, weight: .bold))

                Text("We match interactions with your contacts to show notes, last discussions, and follow-ups.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                actionButton("Sync all contacts") {
                    Task {
                        await syncAll()
                    }
                }

                actionButton("Select specific contacts") {
                    Task {
                        await selectContacts()
                    }
                }

                actionButton("Do not sync") {
                    viewModel.skipContactSyncAndContinue()
                }
            }

            Text("Your contacts stay on your device.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if viewModel.isProcessing {
                ProgressView("Syncing contacts...")
                    .tint(primaryBlue)
            }

            Spacer()
        }
        .disabled(viewModel.isProcessing)
        .sheet(isPresented: $showingPicker) {
            ContactPickerSheet(
                onSelect: { contacts in
                    viewModel.importSelectedContactsAndContinue(contacts)
                },
                onCancel: {}
            )
        }
        .alert("Contacts Access Disabled", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                openSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable Contacts access in Settings to use this feature.")
        }
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private func syncAll() async {
        await viewModel.importAllContactsAndContinue()
        if viewModel.errorMessage != nil {
            showingPermissionAlert = true
        }
    }

    private func selectContacts() async {
        let granted = await viewModel.contactImportService.requestAccess()
        guard granted else {
            viewModel.skipContactSyncAndContinue()
            return
        }
        showingPicker = true
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
