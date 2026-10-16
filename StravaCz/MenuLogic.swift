import Foundation

/// Pravidla, které dny a jídla se v UI zobrazují.
enum MenuLogic {
    static func isPlaceholderMeal(_ name: String) -> Bool {
        let n = name.trimmed.lowercased(with: Czech.locale)
        if n.isEmpty { return true }
        return n.range(of: #"^(oběd|obed|polévka|polevka)\s*\d*$"#, options: .regularExpression) != nil
    }

    static func isHolidayMeal(_ name: String) -> Bool {
        let n = name.lowercased(with: Czech.locale)
        let markers = ["nevaří se", "nevarí se", "nevaříme", "nevarime", "zavřeno", "zavreno"]
        return markers.contains { n.contains($0) }
    }

    static func hasRealMeals(_ day: MenuDay) -> Bool {
        day.meals.contains { !$0.isSoup && !isHolidayMeal($0.name) && !isPlaceholderMeal($0.name) }
    }

    /// Dny s pravými jídly + svátek hned po dni s jídly.
    static func visibleDays(_ days: [MenuDay]) -> [MenuDay] {
        days.enumerated().compactMap { (index, day) -> MenuDay? in
            if hasRealMeals(day) { return day }
            let isHoliday = day.meals.contains { isHolidayMeal($0.name) }
            let previousHasMeals = index > 0 && hasRealMeals(days[index - 1])
            return (isHoliday && previousHasMeals) ? day : nil
        }
    }
}

struct MealGroup: Identifiable {
    let title: String
    let meals: [MealOption]
    var id: String { title }
}

/// Seskupí jídla podle typu a zachová pořadí, v jakém přišla z API.
func orderedGroups(_ meals: [MealOption]) -> [MealGroup] {
    var order: [String] = []
    var buckets: [String: [MealOption]] = [:]
    for meal in meals {
        if buckets[meal.typeKey] == nil { order.append(meal.typeKey) }
        buckets[meal.typeKey, default: []].append(meal)
    }
    return order.map { MealGroup(title: $0, meals: buckets[$0] ?? []) }
}
