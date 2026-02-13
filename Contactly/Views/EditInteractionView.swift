import SwiftUI

struct EditInteractionView: View {
    let contact: Contact
    @Binding var interaction: Interaction
    var onSave: (Interaction) -> Void
    var onDelete: (Interaction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var hasFollowUpDate: Bool
    @State private var showingDeleteAlert = false

    init(
        contact: Contact,
        interaction: Binding<Interaction>,
        onSave: @escaping (Interaction) -> Void,
        onDelete: @escaping (Interaction) -> Void
    ) {
        self.contact = contact
        _interaction = interaction
        self.onSave = onSave
        self.onDelete = onDelete
        _hasFollowUpDate = State(initialValue: interaction.wrappedValue.followUpDate != nil)
    }

    var body: some View {
        Form {
            Section("Interaction") {
                LabeledContent("Contact", value: contact.fullName.isEmpty ? "No Name" : contact.fullName)
                DatePicker("Date", selection: $interaction.startDate, displayedComponents: [.date, .hourAndMinute])
            }

            Section("Notes") {
                TextEditor(text: $interaction.notes)
                    .frame(minHeight: 140)
            }

            Section("Follow-up") {
                Toggle("Set follow-up date", isOn: $hasFollowUpDate.animation(.easeInOut(duration: 0.2)))
                if hasFollowUpDate {
                    DatePicker(
                        "Date",
                        selection: Binding(
                            get: { interaction.followUpDate ?? interaction.startDate },
                            set: { interaction.followUpDate = $0 }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }

            Section {
                Button("Delete Interaction", role: .destructive) {
                    showingDeleteAlert = true
                }
            }
        }
        .navigationTitle("Edit Interaction")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveInteraction()
                }
                .disabled(interaction.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .foregroundStyle(AppTheme.accent)
            }
        }
        .alert("Delete interaction?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onDelete(interaction)
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private func saveInteraction() {
        interaction.notes = interaction.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        interaction.followUpDate = hasFollowUpDate ? interaction.followUpDate : nil
        withAnimation(.easeInOut(duration: 0.2)) {
            onSave(interaction)
        }
        dismiss()
    }
}
