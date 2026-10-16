import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            LogoBadge(size: 92)
            Text("Dobré jídlo\nzačíná tady.")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            ProgressView()
                .controlSize(.large)
                .padding(.top, 24)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
}
