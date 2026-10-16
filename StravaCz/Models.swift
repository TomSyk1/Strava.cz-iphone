import Foundation

// MARK: - API modely

enum MealType { case soup, main, unknown }

struct Allergen { let code: String; let name: String }

struct StravaUser {
    var username: String
    var fullName: String?
    var email: String?
    var balance: Double?
    var currency: String = "Kč"
    var canteenName: String?
    var canteenNumber: String
}

struct StravaMeal {
    let id: Int
    let dateKey: String
    let type: MealType
    let typeLabel: String
    let variant: String
    let name: String
    let description: String?
    let price: Double?
    let ordered: Bool
    let canOrder: Bool
    let canCancel: Bool
    let orderRestriction: String
    let cancelRestriction: String
    let deadline: Date?
    let allergens: [Allergen]
}

struct ApiMenuDay {
    let dateKey: String
    let date: Date
    let meals: [StravaMeal]
    let noSchool: Bool
    let autoOrdered: Bool
    let statusCode: String
}

struct OrderResult { let changedIds: [Int]; let unchangedIds: [Int] }

struct StravaApiError: LocalizedError {
    let message: String
    var apiCode: Int? = nil
    var errorDescription: String? { message }
}

// MARK: - Modely pro UI

struct MealOption: Identifiable, Equatable {
    let id: String
    let name: String
    let variant: String
    let typeKey: String
    var price: Double?
    var ordered: Bool
    var canOrder: Bool
    var canCancel: Bool
    var isSoup: Bool
    var restriction: String
}

struct MenuDay: Identifiable {
    let dateKey: String
    let date: Date
    let deadline: Date?
    let meals: [MealOption]
    let noSchool: Bool
    var id: String { dateKey }
}

/// Klíč výběru: jeden den + jedna skupina jídel (např. "Jídlo").
struct SelectionKey: Hashable { let date: String; let type: String }

/// Hodnota = ID vybraného jídla, nil = "Neobjednávat".
typealias MealSelection = [SelectionKey: String?]

struct SavedCredentials: Codable { let username: String; let password: String; let canteen: String }
