import SwiftUI
import SwiftData

struct RootView: View {
  @Environment(\.modelContext) private var modelContext
  @State private var store = FocusWorkoutStore()

  var body: some View {
    FocusWorkoutView(store: store)
      .task {
        store.bindModelContext(modelContext)
      }
  }
}

#Preview("Light") {
  RootView()
    .preferredColorScheme(.light)
}

#Preview("Dark") {
  RootView()
    .preferredColorScheme(.dark)
}
