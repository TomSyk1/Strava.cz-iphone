import SwiftUI

struct DayCard: View {
    let day: MenuDay
    let selection: MealSelection
    let onSelect: (SelectionKey, String?) -> Void
    let onImages: (String) -> Void

    private func choice(_ key: SelectionKey) -> String? { selection[key] ?? nil }

    var body: some View {
        let groups = orderedGroups(day.meals.filter {
            !$0.isSoup && !MenuLogic.isPlaceholderMeal($0.name) && !MenuLogic.isHolidayMeal($0.name)
        })
        let soups = day.meals.filter {
            $0.isSoup && !MenuLogic.isPlaceholderMeal($0.name) && !MenuLogic.isHolidayMeal($0.name)
        }
        let hasLunch = groups.contains { choice(SelectionKey(date: day.dateKey, type: $0.title)) != nil }

        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                header
                if groups.isEmpty && soups.isEmpty {
                    Text("V tento den se nevaří.").foregroundStyle(Theme.onSurfaceVariant)
                }
                ForEach(soups) { soup in soupRow(soup, hasLunch: hasLunch) }
                ForEach(groups) { group in groupView(group) }
            }
            .padding(16)
        }
    }

    // MARK: - Části karty

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar").font(.title3).foregroundStyle(Theme.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(Czech.longDate(day.date)).font(.title3.bold())
                if let deadline = day.deadline {
                    let passed = deadline < Date()
                    Text((passed ? "Uzávěrka uplynula · " : "Objednávat do ") + Czech.deadline(deadline))
                        .font(.footnote)
                        .foregroundStyle(passed ? Theme.error : Theme.onSurfaceVariant)
                }
            }
        }
    }

    private func soupRow(_ soup: MealOption, hasLunch: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: hasLunch ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(hasLunch ? Theme.primary : Theme.outline)
            VStack(alignment: .leading, spacing: 2) {
                Text(soup.name)
                Text(hasLunch ? "Polévka · součást objednaného obědu" : "Polévka · žádný oběd není objednán")
                    .font(.footnote)
                    .foregroundStyle(Theme.onSurfaceVariant)
            }
        }
    }

    private func groupView(_ group: MealGroup) -> some View {
        let key = SelectionKey(date: day.dateKey, type: group.title)
        let current = choice(key)
        let ordered = group.meals.first(where: { $0.ordered })
        let canChange = ordered == nil || ordered?.canCancel == true
        let noneEnabled = canChange && (ordered != nil || group.meals.contains { $0.canOrder })

        return VStack(alignment: .leading, spacing: 4) {
            Divider().padding(.vertical, 4)
            Text(group.title).font(.headline).foregroundStyle(Theme.primary)

            ForEach(group.meals) { meal in
                let enabled = canChange && (meal.id == ordered?.id || meal.canOrder)
                HStack(spacing: 4) {
                    Button { if enabled { onSelect(key, meal.id) } } label: {
                        HStack(spacing: 12) {
                            RadioMark(selected: current == meal.id)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meal.name).font(.body).multilineTextAlignment(.leading)
                                Text(detail(for: meal, enabled: enabled))
                                    .font(.footnote)
                                    .foregroundStyle(Theme.onSurfaceVariant)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                    .opacity(enabled ? 1 : 0.5)

                    Button("Obrázky") { onImages(meal.name) }
                        .font(.subheadline)
                        .buttonStyle(.borderless)
                }
            }

            Button { if noneEnabled { onSelect(key, nil) } } label: {
                HStack(spacing: 12) {
                    RadioMark(selected: current == nil)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Neobjednávat")
                        Text("Bez obědu").font(.footnote).foregroundStyle(Theme.onSurfaceVariant)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!noneEnabled)
            .opacity(noneEnabled ? 1 : 0.5)
        }
    }

    private func detail(for meal: MealOption, enabled: Bool) -> String {
        var text = meal.variant
        if let price = meal.price { text += " · \(Czech.price(price)) Kč" }
        if !enabled { text += " · " + (meal.restriction.isEmpty ? "nelze změnit" : meal.restriction) }
        return text
    }
}
