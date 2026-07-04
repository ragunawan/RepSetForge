import SwiftUI

/// A 1-10 Rate of Perceived Exertion picker, shared by the quest-level and
/// per-exercise "how hard did this feel?" journal fields. `nil` means
/// "not rated" and is always offered as an explicit option.
struct PerceivedEffortPicker: View {
    @Binding var effort: Int?

    var body: some View {
        Picker("Perceived Effort", selection: $effort) {
            Text("Not Rated").tag(Int?.none)
            ForEach(1...10, id: \.self) { value in
                Text("\(value)/10").tag(Int?.some(value))
            }
        }
    }
}
