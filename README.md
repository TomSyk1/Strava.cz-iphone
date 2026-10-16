# Strava.cz – iOS (SwiftUI)

Přepis nativní Android appky [Strava-native-android](https://github.com/Vasik96/Strava-native-android) do SwiftUI.
Funkce: přihlášení do jídelny, jídelníček po dnech, objednání / zrušení obědů, zůstatek, uzávěrky,
Google Obrázky k jídlu, zapamatované přihlášení (iOS Keychain). Vyžaduje iOS 16+.

> Kód zatím nebyl zkompilován na reálném Xcode. Pokud build hlásí chybu, pošli mi ji a opravím ji.

## Jak získat .ipa

### A) Bez Macu – GitHub Actions
1. Vytvoř nový GitHub repozitář a nahraj do něj obsah této složky (včetně `.github`).
2. Záložka **Actions → Build unsigned IPA → Run workflow** (nebo stačí push do `main`).
3. Po dokončení stáhni artefakt **StravaCz-ipa** (uvnitř je `StravaCz.ipa`, nepodepsané).

### B) S Macem – Xcode
```bash
brew install xcodegen
xcodegen generate
open StravaCz.xcodeproj
```
V Xcode vyber svůj Apple ID v *Signing & Capabilities* a dej Run na iPhone.

## Instalace na iPhone (sideload)
1. iPhone: **Nastavení → Soukromí a zabezpečení → Režim pro vývojáře** → zapnout a restartovat.
2. Podepiš a nainstaluj `StravaCz.ipa` přes **Sideloadly** (Windows/Mac, USB) nebo **AltStore / SideStore**.
3. S bezplatným Apple ID platí podpis 7 dní – appku pak stačí znovu podepsat (AltStore to umí automaticky přes Wi-Fi).
4. Při prvním spuštění případně: **Nastavení → Obecné → VPN a správa zařízení** → důvěřovat svému Apple ID.

## Rozdíly oproti Android verzi
- Přihlašovací údaje jsou v Keychainu, ne v šifrovaném SharedPreferences.
- Při automatickém přihlášení se údaje smažou jen když je server odmítne (při výpadku sítě zůstanou).
- Den, kdy se nevaří, ukáže kartu „V tento den se nevaří“ (v Androidu zůstal jen čip bez karty).
- Obnovení jídelníčku i tažením dolů.

## Struktura
- `StravaAPI.swift` – klient neoficiálního API (login, jídelníček, objednávky), port z `StravaApi.kt`
- `StravaRepository.swift` – převod na UI modely + ukládání změn
- `AppViewModel.swift` – stav appky
- `Views/` – obrazovky (přihlášení, jídelníček, karta dne, Google Obrázky)
