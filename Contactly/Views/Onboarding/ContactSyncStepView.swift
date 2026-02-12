import Contacts
import SwiftUI
import UIKit

struct ContactSyncStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    @State private var showingPicker = false
    @State private var showingPermissionAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Choose how to sync contacts")
                .font(.headline)

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

            if viewModel.isProcessing {
                ProgressView("Syncing contacts...")
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
        .alert("Contacts Access Needed", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                openSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow contacts access in Settings to sync your address book.")
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
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
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
            showingPermissionAlert = true
            return
        }
        showingPicker = true
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
