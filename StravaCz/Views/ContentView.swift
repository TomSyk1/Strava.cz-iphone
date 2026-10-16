import SwiftUI

struct ContentView: View {
    @StateObject private var vm = AppViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                switch vm.screen {
                case .loading: LoadingView().transition(.opacity)
                case .login: LoginView(vm: vm).transition(.opacity)
                case .menu: MenuView(vm: vm).transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: vm.screen)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { LogoBadge(size: 34) }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("Strava.cz").font(.headline)
                        Text(vm.loggedIn ? "Jídelníček a objednávky" : "Přihlášení do jídelny")
                            .font(.caption2)
                            .foregroundStyle(Theme.onSurfaceVariant)
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if vm.loggedIn {
                        Button { Task { await vm.refreshMenu() } } label: { Image(systemName: "arrow.clockwise") }
                            .disabled(vm.loading)
                        Button { vm.showLogoutDialog = true } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                        .disabled(vm.loading)
                    }
                }
            }
        }
        .task { await vm.start() }
        .alert("Odhlásit se?", isPresented: $vm.showLogoutDialog) {
            Button("Odhlásit", role: .destructive) { Task { await vm.logout() } }
            Button("Zůstat", role: .cancel) {}
        } message: {
            Text("Opravdu se chcete odhlásit ze Strava.cz?")
        }
    }
}
