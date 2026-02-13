import SwiftUI

struct WatchContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "drop.fill")
                .foregroundStyle(.tint)
            Text("Waterline")
                .font(.headline)
        }
    }
}

#Preview {
    WatchContentView()
}
