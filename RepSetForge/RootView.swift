import SwiftUI
import SwiftData

struct RootView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase
  @State private var store = FocusWorkoutStore(activityController: .shared)

  var body: some View {
    FocusWorkoutView(store: store)
      .task {
        store.bindModelContext(modelContext)
      }
      .onChange(of: scenePhase) { _, phase in
        if phase == .active {
          store.reassertLiveActivity()
        }
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
