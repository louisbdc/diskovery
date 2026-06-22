import SwiftUI

struct ContentView: View {
    @State private var selectedToolID: String?
    @State private var store = SessionStore()

    var body: some View {
        NavigationSplitView {
            List(ToolRegistry.all, selection: $selectedToolID) { tool in
                Label(tool.name, systemImage: tool.icon)
                    .tag(tool.id)
            }
            .navigationTitle("Outils")
            .frame(minWidth: 200)
        } detail: {
            if let tool = ToolRegistry.all.first(where: { $0.id == selectedToolID }) {
                tool.makeView(store)
            } else {
                ContentUnavailableView(
                    "Aucun outil sélectionné",
                    systemImage: "sidebar.left",
                    description: Text("Choisissez un outil dans la barre latérale.")
                )
            }
        }
    }
}
