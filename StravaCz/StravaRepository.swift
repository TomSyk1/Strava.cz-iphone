import Foundation

/// Převádí API modely na modely pro UI a řeší ukládání změn objednávek.
final class StravaRepository {
    private let api = StravaAPI()

    func login(username: String, password: String, canteen: String) async throws {
        _ = try await api.login(username: username, password: password, canteen: canteen)
    }

    func logout() async { await api.logout() }

    func balance() async -> Double? { await api.user?.balance }

    func userName() async -> String? {
        let user = await api.user
        if let name = user?.fullName, !name.trimmed.isEmpty { return name }
        if let name = user?.username, !name.trimmed.isEmpty { return name }
        return nil
    }

    func fetchMenu() async throws -> [MenuDay] {
        try await api.fetchMenu().map { (day) -> MenuDay in
            let meals: [MealOption] = day.meals.map { (meal) -> MealOption in
                let label = meal.typeLabel.lowercased()
                let isSoup = meal.type == .soup || label.contains("polév") || label.contains("polev")
                let typeKey: String
                switch meal.type {
                case .main: typeKey = "Jídlo"
                case .soup: typeKey = "Polévka"
                case .unknown: typeKey = meal.typeLabel.trimmed.isEmpty ? "Jídlo" : meal.typeLabel
                }
                let fallbackVariant = meal.typeLabel.trimmed.isEmpty ? "Jídlo" : meal.typeLabel
                return MealOption(
                    id: String(meal.id),
                    name: meal.name,
                    variant: meal.variant.trimmed.isEmpty ? fallbackVariant : meal.variant,
                    typeKey: typeKey,
                    price: meal.price,
                    ordered: meal.ordered,
                    canOrder: meal.canOrder,
                    canCancel: meal.canCancel,
                    isSoup: isSoup,
                    restriction: meal.ordered ? meal.cancelRestriction : meal.orderRestriction
                )
            }
            let mainDeadline = day.meals.filter { $0.type != .soup }.compactMap { $0.deadline }.min()
            let deadline = mainDeadline ?? day.meals.compactMap { $0.deadline }.min()
            return MenuDay(dateKey: day.dateKey, date: day.date, deadline: deadline, meals: meals, noSchool: day.noSchool)
        }
    }

    /// Uloží rozdíl proti původnímu stavu: pro každou skupinu nejdřív zruší staré jídlo, pak objedná nové.
    func saveOrders(original: MealSelection, selected: MealSelection) async throws {
        let allKeys = Set(selected.keys).union(original.keys)
        let changes = allKeys
            .filter { (selected[$0] ?? nil) != (original[$0] ?? nil) }
            .sorted { ($0.date, $0.type) < ($1.date, $1.type) }

        for key in changes {
            let oldId: String? = original[key] ?? nil
            let newId: String? = selected[key] ?? nil

            if let oldId {
                let day = try await menuDay(key.date)
                let group = day.meals.filter { !$0.isSoup && $0.typeKey == key.type }
                guard let old = group.first(where: { $0.id == oldId }) else {
                    throw StravaApiError(message: "Původní jídlo už není v nabídce. Obnov jídelníček.")
                }
                if old.ordered, let apiId = Int(old.id) { _ = try await api.cancelMeal(apiId) }
            }

            if let newId {
                let day = try await menuDay(key.date)
                guard let fresh = day.meals.first(where: { !$0.isSoup && $0.typeKey == key.type && $0.id == newId }) else {
                    throw StravaApiError(message: "Vybrané jídlo už není v nabídce. Obnov jídelníček.")
                }
                if !fresh.ordered, let apiId = Int(fresh.id) { _ = try await api.orderMeal(apiId) }
            }
        }
    }

    private func menuDay(_ dateKey: String) async throws -> MenuDay {
        guard let day = try await fetchMenu().first(where: { $0.dateKey == dateKey }) else {
            throw StravaApiError(message: "Den \(dateKey) už není v jídelníčku.")
        }
        return day
    }
}
