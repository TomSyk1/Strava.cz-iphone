import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    enum Screen { case loading, login, menu }

    private let repository = StravaRepository()

    @Published var loggedIn = false
    @Published var loading = true

    @Published var username = ""
    @Published var password = ""
    @Published var canteen = ""
    @Published var rememberLogin = true
    @Published var passwordVisible = false

    @Published var userName: String?
    @Published var days: [MenuDay] = []
    @Published var balance: Double?

    @Published var selected: MealSelection = [:]
    @Published var original: MealSelection = [:]

    @Published var error: String?
    @Published var message: String?
    @Published var showLogoutDialog = false

    var dirty: Bool { selected != original }

    var screen: Screen {
        if loggedIn { return .menu }
        return loading ? .loading : .login
    }

    // MARK: - Akce

    /// Automatické přihlášení uloženými údaji při startu appky.
    func start() async {
        guard let saved = CredentialStore.load() else {
            loading = false
            return
        }
        username = saved.username
        password = saved.password
        canteen = saved.canteen
        do {
            try await repository.login(username: saved.username, password: saved.password, canteen: saved.canteen)
            userName = await repository.userName()
            loggedIn = true
            await refreshMenu()
        } catch {
            // Údaje smažeme jen když je server odmítl; při výpadku sítě zůstanou uložené.
            if let apiError = error as? StravaApiError, apiError.apiCode != nil {
                CredentialStore.clear()
            }
            self.error = error.localizedDescription
            loading = false
        }
    }

    func login() async {
        loading = true
        error = nil
        do {
            try await repository.login(username: username.trimmed, password: password, canteen: canteen.trimmed)
            userName = await repository.userName()
            loggedIn = true
            if rememberLogin {
                CredentialStore.save(SavedCredentials(username: username.trimmed, password: password, canteen: canteen.trimmed))
            } else {
                CredentialStore.clear()
            }
            await refreshMenu()
        } catch {
            self.error = error.localizedDescription
            loading = false
        }
    }

    func refreshMenu() async {
        loading = true
        error = nil
        do {
            let result = try await repository.fetchMenu()
            apply(menu: result)
            balance = await repository.balance()
            userName = await repository.userName()
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    func save() async {
        loading = true
        error = nil
        do {
            try await repository.saveOrders(original: original, selected: selected)
            message = "Změny uloženy"
            let refreshed = try await repository.fetchMenu()
            apply(menu: refreshed)
            balance = await repository.balance()
            userName = await repository.userName()
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    func logout() async {
        loading = true
        await repository.logout()
        CredentialStore.clear()
        loggedIn = false
        userName = nil
        days = []
        selected = [:]
        original = [:]
        balance = nil
        password = ""
        loading = false
    }

    func select(_ key: SelectionKey, _ mealId: String?) {
        selected.updateValue(mealId, forKey: key)
    }

    func discardChanges() { selected = original }

    /// Zprávu ("Změny uloženy") po chvíli schová; při nové zprávě se předchozí čekání zruší.
    func dismissMessageAfterDelay() async {
        guard message != nil else { return }
        do { try await Task.sleep(nanoseconds: 2_500_000_000) } catch { return }
        message = nil
    }

    // MARK: - Pomocné

    private func apply(menu: [MenuDay]) {
        days = menu
        let state = Self.selectionState(menu)
        selected = state
        original = state
    }

    private static func selectionState(_ menu: [MenuDay]) -> MealSelection {
        var result: MealSelection = [:]
        for day in menu {
            for group in orderedGroups(day.meals.filter { !$0.isSoup }) {
                let orderedId: String? = group.meals.first(where: { $0.ordered })?.id
                result.updateValue(orderedId, forKey: SelectionKey(date: day.dateKey, type: group.title))
            }
        }
        return result
    }
}
