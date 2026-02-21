import SwiftUI
import UIKit

struct OnboardingView: View {
    let contactRepository: ContactRepository
    @Bindable var userProfileStore: UserProfileStore

    @State private var importService = ContactImportService()
    @State private var isImporting = false
    @State private var showPermissionAlert = false
    @State private var showErrorAlert = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.06), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "person.2.crop.square.stack.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)

                Text("Welcome to Contactly")
                    .font(.system(size: 30, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text("Contactly needs access to your contacts to associate meetings with people you know.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)

                Spacer()

                Button {
                    Task {
                        await importAllContactsAndFinishOnboarding()
                    }
                } label: {
                    Text("Continue")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppTheme.accent)
                        )
                }
                .buttonStyle(PressScaleButtonStyle())
                .disabled(isImporting)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)

            if isImporting {
                ZStack {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                    ProgressView("Importing contacts...")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .alert("Contacts Access Disabled", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable Contacts access in Settings to use this feature.")
        }
        .alert("Import Failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Unable to import all contacts right now. Please try again.")
        }
    }

    private func importAllContactsAndFinishOnboarding() async {
        guard await importService.requestAccess() else {
            showPermissionAlert = true
            return
        }

        isImporting = true
        defer { isImporting = false }

        do {
            let rawContacts = try await importService.fetchAllContactsAsync()
            let mappedContacts = importService.mapContacts(rawContacts)
            let importedCount = saveUniqueContacts(mappedContacts)
            print("[ContactImport] Imported \(importedCount) / \(mappedContacts.count) contacts during onboarding.")
            userProfileStore.completeOnboarding()
        } catch {
            showErrorAlert = true
        }
    }

    private func saveUniqueContacts(_ contacts: [Contact]) -> Int {
        var existingEmails = Set(contactRepository.contacts.compactMap { normalizedEmail($0.email) })
        var existingPhones = Set(contactRepository.contacts.compactMap { normalizedPhone($0.phone) })
        var imported = 0

        for contact in contacts {
            let email = normalizedEmail(contact.email)
            let phone = normalizedPhone(contact.phone)
            let isDuplicateByEmail = email.map { existingEmails.contains($0) } ?? false
            let isDuplicateByPhone = phone.map { existingPhones.contains($0) } ?? false

            if isDuplicateByEmail || isDuplicateByPhone {
                continue
            }

            contactRepository.add(contact)
            if let email {
                existingEmails.insert(email)
            }
            if let phone {
                existingPhones.insert(phone)
            }
            imported += 1
        }

        return imported
    }

    private func normalizedEmail(_ email: String) -> String? {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.isEmpty ? nil : value
    }

    private func normalizedPhone(_ phone: String) -> String? {
        let value = phone.filter { $0.isWholeNumber }
        return value.isEmpty ? nil : value
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
