import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "drop.fill")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Waterline")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
