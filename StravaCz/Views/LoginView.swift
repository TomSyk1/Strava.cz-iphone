import SwiftUI

struct LoginView: View {
    @ObservedObject var vm: AppViewModel
    @FocusState private var focus: Field?

    private enum Field { case user, pass, canteen }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                LogoBadge(size: 100).padding(.top, 28)

                Text("Dobré jídlo\nzačíná tady.")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)

                if !vm.loading {
                    Text("Přihlaste se ke své školní jídelně.")
                        .foregroundStyle(Theme.onSurfaceVariant)
                        .padding(.top, 8)
                }

                SurfaceCard(radius: 28) {
                    VStack(spacing: 12) {
                        fields
                        rememberRow
                        if let error = vm.error { ErrorCard(text: error) }
                        loginButton
                    }
                    .padding(18)
                }
                .padding(.top, 24)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var fields: some View {
        VStack(spacing: 12) {
            LabeledField(icon: "person") {
                TextField("Uživatelské jméno", text: $vm.username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .user)
                    .submitLabel(.next)
                    .onSubmit { focus = .pass }
            }

            LabeledField(icon: "lock") {
                Group {
                    if vm.passwordVisible {
                        TextField("Heslo", text: $vm.password)
                    } else {
                        SecureField("Heslo", text: $vm.password)
                    }
                }
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: .pass)
                .submitLabel(.next)
                .onSubmit { focus = .canteen }

                Button(vm.passwordVisible ? "Skrýt" : "Zobrazit") { vm.passwordVisible.toggle() }
                    .font(.subheadline)
            }

            LabeledField(icon: "fork.knife") {
                TextField("Číslo jídelny", text: $vm.canteen)
                    .keyboardType(.numberPad)
                    .focused($focus, equals: .canteen)
            }
        }
    }

    private var rememberRow: some View {
        Button { vm.rememberLogin.toggle() } label: {
            HStack(spacing: 12) {
                Image(systemName: vm.rememberLogin ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(vm.rememberLogin ? Theme.primary : Theme.outline)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Zapamatovat přihlášení").fontWeight(.medium).foregroundStyle(.primary)
                    Text("Údaje jsou uložené v Keychainu v zařízení")
                        .font(.footnote)
                        .foregroundStyle(Theme.onSurfaceVariant)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var loginButton: some View {
        Button {
            focus = nil
            Task { await vm.login() }
        } label: {
            HStack(spacing: 8) {
                if vm.loading {
                    ProgressView().tint(Theme.onPrimary)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Přihlásit se").fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .foregroundStyle(Theme.onPrimary)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.primary))
        }
        .buttonStyle(.plain)
        .disabled(vm.loading)
        .opacity(vm.loading ? 0.7 : 1)
    }
}
