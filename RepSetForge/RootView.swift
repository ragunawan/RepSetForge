import SwiftUI

struct RootView: View {
  @State private var store = FocusWorkoutStore()

  var body: some View {
    FocusWorkoutView(store: store)
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
