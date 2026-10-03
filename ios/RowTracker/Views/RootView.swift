import SwiftUI

struct RootView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.rower")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(.tint)
            Text("Hello RowTracker")
                .font(.largeTitle)
                .fontWeight(.semibold)
            Text("iOS port scaffold — Phase 1")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    RootView()
}
