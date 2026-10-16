import Foundation

/// Nativní klient pro neoficiální JSON API Strava.cz (port z Kotlin verze).
/// API je nedokumentované a může se změnit; nelogujeme přihlašovací údaje, SID ani surové odpovědi.
actor StravaAPI {
    private let baseURL: String
    private let language: String
    private let timeout: TimeInterval
    private let session: URLSession

    private var canteenNumber: String?
    private var sid: String?
    private var s5url: String?
    private(set) var user: StravaUser?

    init(baseURL: String = "https://app.strava.cz", language: String = "EN", timeout: TimeInterval = 30) {
        self.baseURL = baseURL.withoutTrailingSlash
        self.language = language
        self.timeout = timeout
        // Ephemeral = cookies jen v paměti; URLSession je mezi požadavky drží sama.
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        self.session = URLSession(configuration: config)
    }

    var isLoggedIn: Bool { !(sid ?? "").isEmpty && !(s5url ?? "").isEmpty }

    // MARK: - Přihlášení

    func login(username: String, password: String, canteen: String) async throws -> StravaUser {
        let name = username.trimmed
        let canteenNo = canteen.trimmed
        guard !name.isEmpty else { throw StravaApiError(message: "Zadej uživatelské jméno.") }
        guard !password.trimmed.isEmpty else { throw StravaApiError(message: "Zadej heslo.") }
        guard !canteenNo.isEmpty else { throw StravaApiError(message: "Zadej číslo jídelny.") }

        await primeWebSession()

        let payload: JSON = [
            "cislo": canteenNo,
            "jmeno": name,
            "heslo": password,
            "zustatPrihlasen": true,
            "environment": "W",
            "lang": language,
        ]
        let response = try await post("/api/login", payload, allowUnauthenticated: true)
        try checkApiError(response)

        let newSid = response.str("sid")
        guard !newSid.isEmpty else { throw StravaApiError(message: "Přihlášení nevrátilo platnou session (SID).") }
        let newS5Url = response.str("s5url")
        guard !newS5Url.isEmpty else { throw StravaApiError(message: "Přihlášení nevrátilo adresu služby jídelny (s5url).") }
        let account = response.obj("uzivatel") ?? [:]

        canteenNumber = canteenNo
        sid = newSid
        s5url = newS5Url

        let currency = account.str("mena")
        let parsed = StravaUser(
            username: name,
            fullName: account.str("jmeno").nonBlank,
            email: account.str("email").nonBlank,
            balance: account.str("konto").moneyOrNil,
            currency: currency.isEmpty ? "Kč" : currency,
            canteenName: account.str("nazevJidelny").nonBlank,
            canteenNumber: canteenNo
        )
        user = parsed
        return parsed
    }

    func logout() async {
        if isLoggedIn, let url = s5url, var payload = try? authenticatedPayload() {
            payload["url"] = url
            _ = try? await post("/api/logOut", payload)
        }
        sid = nil
        s5url = nil
        canteenNumber = nil
        user = nil
        session.configuration.httpCookieStorage?.removeCookies(since: .distantPast)
    }

    // MARK: - Jídelníček

    func fetchMenu() async throws -> [ApiMenuDay] {
        let url = try requireS5url()
        var payload = try authenticatedPayload()
        payload["s5url"] = url
        payload["konto"] = 0
        payload["podminka"] = ""
        let response = try await post("/api/objednavky", payload)
        try checkApiError(response)
        return parseMenu(response)
    }

    // MARK: - Objednávání

    func orderMeal(_ id: Int) async throws -> OrderResult { try await setMealsOrdered([id], ordered: true) }
    func cancelMeal(_ id: Int) async throws -> OrderResult { try await setMealsOrdered([id], ordered: false) }

    /// Objedná / zruší jídla jako jednu transakci a ověří uložený stav.
    private func setMealsOrdered(_ ids: [Int], ordered: Bool) async throws -> OrderResult {
        try ensureLoggedIn()
        var seen = Set<Int>()
        let distinctIds = ids.filter { seen.insert($0).inserted }
        if distinctIds.isEmpty { return OrderResult(changedIds: [], unchangedIds: []) }

        // ID (`veta`) nejsou trvalá – vždy je hledáme v čerstvě stáhnutém jídelníčku.
        let currentMenu = try await fetchMenu()
        var allMeals: [Int: StravaMeal] = [:]
        for meal in currentMenu.flatMap({ $0.meals }) { allMeals[meal.id] = meal }

        let missing = distinctIds.filter { allMeals[$0] == nil }
        if !missing.isEmpty {
            let list = missing.map { String($0) }.joined(separator: ", ")
            throw StravaApiError(message: "Jídlo už není v aktuálním jídelníčku: \(list). Obnov jídelníček.")
        }

        let targetMeals = distinctIds.compactMap { allMeals[$0] }
        let unchanged = targetMeals.filter { $0.ordered == ordered }.map { $0.id }
        let toChange = targetMeals.filter { $0.ordered != ordered }
        if toChange.isEmpty { return OrderResult(changedIds: [], unchangedIds: unchanged) }

        // Ještě před odesláním ověř, že akci jídelna povoluje.
        if let blocked = toChange.first(where: { ordered ? !$0.canOrder : !$0.canCancel }) {
            let reason = ordered ? blocked.orderRestriction : blocked.cancelRestriction
            let verb = ordered ? "objednat" : "odhlásit"
            let why = reason.isEmpty ? "jídelna změnu nepovoluje" : reason
            throw StravaApiError(message: "Nelze \(verb) '\(blocked.name)': \(why)")
        }

        do {
            let url = try requireS5url()
            for meal in toChange {
                var stage = try authenticatedPayload()
                stage["url"] = url
                stage["veta"] = String(meal.id)
                stage["pocet"] = ordered ? "1" : "0"
                let stageResponse = try await post("/api/pridejJidloS5", stage)
                try checkApiError(stageResponse)
                if let konto = stageResponse.str("konto").moneyOrNil { user?.balance = konto }
            }

            var save = try authenticatedPayload()
            save["url"] = url
            save["xml"] = NSNull()
            let saveResponse = try await post("/api/saveOrders", save)
            try checkApiError(saveResponse)
            if let konto = saveResponse.str("konto").moneyOrNil { user?.balance = konto }

            var verified: [Int: StravaMeal] = [:]
            for meal in try await fetchMenu().flatMap({ $0.meals }) { verified[meal.id] = meal }
            let notSaved = toChange.filter { verified[$0.id]?.ordered != ordered }
            if !notSaved.isEmpty {
                let names = notSaved.map { $0.name }.joined(separator: ", ")
                throw StravaApiError(message: "Server změnu nepotvrdil pro: \(names).")
            }
            return OrderResult(changedIds: toChange.map { $0.id }, unchangedIds: unchanged)
        } catch {
            // Při chybě zahodíme rozpracované změny (stejně jako Python knihovna).
            try? await reloadAndDiscardStagedChanges()
            if let apiError = error as? StravaApiError { throw apiError }
            throw StravaApiError(message: "Objednávku se nepodařilo dokončit: \(error.localizedDescription)")
        }
    }

    private func reloadAndDiscardStagedChanges() async throws {
        var payload = try authenticatedPayload()
        payload["url"] = try requireS5url()
        payload["getText"] = true
        payload["checkVersion"] = true
        payload["resetTables"] = true
        payload["frontendFunction"] = "refreshInformations"
        let response = try await post("/api/nactiVlastnostiPA", payload)
        try checkApiError(response)
    }

    // MARK: - Pomocné

    private func authenticatedPayload() throws -> JSON {
        try ensureLoggedIn()
        return [
            "cislo": canteenNumber ?? "",
            "sid": sid ?? "",
            "lang": language,
            "ignoreCert": "false",
        ]
    }

    private func requireS5url() throws -> String {
        guard let url = s5url, !url.isEmpty else { throw StravaApiError(message: "Nejsi přihlášený. Nejdřív se přihlas.") }
        return url
    }

    private func ensureLoggedIn() throws {
        if !isLoggedIn || (canteenNumber ?? "").trimmed.isEmpty {
            throw StravaApiError(message: "Nejsi přihlášený. Nejdřív se přihlas.")
        }
    }

    private func applyBrowserHeaders(_ request: inout URLRequest, isPost: Bool) {
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9,cs;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue(baseURL, forHTTPHeaderField: "Origin")
        request.setValue(baseURL + "/en/prihlasit-se?jidelna", forHTTPHeaderField: "Referer")
        request.setValue("empty", forHTTPHeaderField: "sec-fetch-dest")
        request.setValue("cors", forHTTPHeaderField: "sec-fetch-mode")
        request.setValue("same-origin", forHTTPHeaderField: "sec-fetch-site")
        if isPost { request.setValue("text/plain;charset=UTF-8", forHTTPHeaderField: "Content-Type") }
    }

    /// Před voláním JSON API otevřeme stránku s přihlášením, aby server nastavil session cookie.
    /// Best-effort – případnou chybu odhalí až samotný login.
    private func primeWebSession() async {
        guard let url = URL(string: baseURL + "/en/prihlasit-se?jidelna") else { return }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        applyBrowserHeaders(&request, isPost: false)
        _ = try? await session.data(for: request)
    }

    private func post(_ path: String, _ body: JSON, allowUnauthenticated: Bool = false) async throws -> JSON {
        if !allowUnauthenticated { try ensureLoggedIn() }
        guard let url = URL(string: baseURL + path) else { throw StravaApiError(message: "Neplatná adresa: \(path)") }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        applyBrowserHeaders(&request, isPost: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.withoutEscapingSlashes])

        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw StravaApiError(message: "Strava.cz neodpověděla v limitu \(Int(timeout)) s při požadavku \(path). Zkontroluj připojení a zkus to znovu.")
        } catch {
            throw StravaApiError(message: "Spojení se Strava.cz selhalo: \(error.localizedDescription)")
        }

        let data = result.0
        let status = (result.1 as? HTTPURLResponse)?.statusCode ?? 0
        let text = (String(data: data, encoding: .utf8) ?? "").trimmed

        if text.isEmpty {
            if !(200...299).contains(status) { throw StravaApiError(message: "Strava.cz vrátila HTTP \(status).") }
            return ["_httpStatus": status] // některé endpointy vrací prázdné tělo (např. logout)
        }

        var parsed: JSON
        switch text {
        case "true": parsed = ["_bareJson": true]
        case "false": parsed = ["_bareJson": false]
        default:
            guard let object = (try? JSONSerialization.jsonObject(with: data)) as? JSON else {
                throw StravaApiError(message: "Neplatná JSON odpověď z \(path) (HTTP \(status)).")
            }
            parsed = object
        }
        if !(200...299).contains(status) && parsed["state"] == nil {
            throw StravaApiError(message: "Strava.cz vrátila HTTP \(status).")
        }
        parsed["_httpStatus"] = status
        return parsed
    }

    private func checkApiError(_ json: JSON) throws {
        if json.str("state").lowercased() == "error" {
            let code = json.int("number", default: -1)
            let message = json.str("message").trimmed
            throw StravaApiError(message: message.isEmpty ? "Strava.cz požadavek odmítla." : message, apiCode: code)
        }
        let status = json.int("_httpStatus", default: 200)
        if !(200...299).contains(status) { throw StravaApiError(message: "Strava.cz vrátila HTTP \(status).") }
    }

    // MARK: - Parsování jídelníčku

    private func parseMenu(_ root: JSON) -> [ApiMenuDay] {
        var rowsByDay: [String: [JSON]] = [:]
        let tableKeys = root.keys
            .filter { $0.hasPrefix("table") }
            .sorted { (Int($0.dropFirst(5)) ?? Int.max) < (Int($1.dropFirst(5)) ?? Int.max) }

        for key in tableKeys {
            guard let rows = root[key] as? [Any] else { continue }
            for case let row as JSON in rows {
                guard let dateKey = Czech.parseDateKey(row.str("datum")) else { continue }
                rowsByDay[dateKey, default: []].append(row)
            }
        }

        var days: [ApiMenuDay] = []
        for dateKey in rowsByDay.keys.sorted() {
            guard let rows = rowsByDay[dateKey], let date = Czech.date(fromKey: dateKey) else { continue }
            let meals = rows.compactMap { parseMeal($0) }
            let dayCode = rows.first?.obj("omezeniObj")?.str("den") ?? ""
            let closedByName = meals.contains {
                $0.name.caseInsensitiveCompare("Nevaří se") == .orderedSame
                    || $0.name.caseInsensitiveCompare("Státní svátek") == .orderedSame
            }
            days.append(ApiMenuDay(
                dateKey: dateKey,
                date: date,
                meals: meals,
                noSchool: dayCode == "VP" || closedByName,
                autoOrdered: dayCode != "T",
                statusCode: dayCode
            ))
        }
        return days
    }

    private func parseMeal(_ row: JSON) -> StravaMeal? {
        guard let id = Int(row.str("veta").trimmed) else { return nil }
        let kindLabel = row.str("druh_popis")
        var name = row.str("nazev")
        if name.trimmed.isEmpty { name = kindLabel }
        if name.trimmed.isEmpty { return nil }
        // Nevyplněné sloty ("Oběd 1") bez názvu jídla ignorujeme.
        if name == kindLabel, name.range(of: #"^(?i)(oběd|obed|jídlo|jidlo)\s*\d+$"#, options: .regularExpression) != nil {
            return nil
        }
        guard let dateKey = Czech.parseDateKey(row.str("datum")) else { return nil }

        let restrictions = row.obj("omezeniObj") ?? [:]
        let orderRestriction = restrictions.str("obj")
        let cancelRestriction = restrictions.str("zm")

        let typeCode = row.str("druh").uppercased()
        let type: MealType
        if typeCode.hasPrefix("P") { type = .soup } else if typeCode.hasPrefix("O") { type = .main } else { type = .unknown }

        var allergens: [Allergen] = []
        if let list = row["alergeny"] as? [Any] {
            for item in list {
                guard let pair = item as? [Any], pair.count >= 2 else { continue }
                allergens.append(Allergen(code: jsonString(pair[0]), name: jsonString(pair[1])))
            }
        }

        return StravaMeal(
            id: id,
            dateKey: dateKey,
            type: type,
            typeLabel: kindLabel,
            variant: kindLabel,
            name: name,
            description: row.str("delsiPopis").nonBlank,
            price: row.str("cena").moneyOrNil,
            ordered: row.int("pocet") > 0 || row.str("pocet") == "1",
            canOrder: orderRestriction.isEmpty,
            canCancel: cancelRestriction.isEmpty,
            orderRestriction: restrictionText(orderRestriction),
            cancelRestriction: restrictionText(cancelRestriction),
            deadline: Czech.parseDateTime(row.str("casKonec")),
            allergens: allergens
        )
    }

    private func restrictionText(_ code: String) -> String {
        switch code {
        case "": return ""
        case "C": return "Uzávěrka objednávek již proběhla."
        case "I": return "Toto jídlo nelze objednat samostatně."
        case "V": return "V tento den se nevaří."
        default: return "Změna není povolena (kód \(code))."
        }
    }
}

private extension String {
    /// nil pro prázdný / bílý řetězec (Kotlin `takeIf { it.isNotBlank() }`).
    var nonBlank: String? { trimmed.isEmpty ? nil : self }
}
