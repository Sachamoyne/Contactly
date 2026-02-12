import SwiftUI

struct ContentView: View {
    @State private var viewModel = ContactsViewModel(repository: ContactRepository())

    var body: some View {
        ContactsListView(viewModel: viewModel)
    }
}
