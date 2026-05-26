# AtollCard Localization (DE/EN/FR)

**Status:** Draft (User-Review pending)
**Date:** 2026-05-26
**Author:** Dominik Weckherlin (with Claude/Larry)
**Spec Owner:** Dominik
**Target Release:** Welle E — Sub-Projekt 7 von 9

---

## 1. Kontext & Problem

### Heutiger Zustand

iOS-App AtollCard ist deutschsprachig hardcoded. Public Card Page (`/c/<slug>`) ebenfalls. Dominik bedient:
- Schweizer Schüler (DE)
- Internationale Trial-Diver in Dauin (EN)
- Französischsprachige Kunden (FR-Schweiz und FR-Frankreich)

### Pain-Points

1. Trial-Dive-Tourist scannt den QR mit iPhone, landet auf DE-Seite, versteht nichts vom Lead-Form
2. Englische Schüler installieren die App ohne Erfolg, weil alles DE
3. Französische Schüler ähnlich, plus die FR-CH-Community in der Westschweiz braucht das speziell

### Zielbild

iOS-App + Public Card Page sprechen DE/EN/FR. iOS folgt System-Locale, mit manuellem Override in Settings. Public-Page detected die Sprache aus `Accept-Language`, mit `?lang=<de|en|fr>`-Override und sichtbarem LanguageSwitcher.

Web-Inbox + Adressbuch + iOS-Inbox bleiben DE-only — die User-Basis ist Dominik selber, der spricht eh DE.

---

## 2. Architektur-Entscheidung

**iOS String Catalog (`.xcstrings`) — modern, native, Xcode-15+.**

Begründung gegenüber Alternativen:
- Plurals + Regionalisierung built-in
- Xcode UI zeigt Coverage pro Sprache
- Auto-Extraction aus `Text(...)`-Code — kein manuelles Tagging
- Standard fürs iOS-26-Ökosystem

**Web mit hand-gewartetem Translations-Map** (kein i18next / react-intl).

Begründung:
- Nur eine Seite (PublicCardScreen) braucht i18n — Adressbuch + Inbox bleiben DE only
- ~20 Keys — eine TypeScript-Map ist kürzer als die i18next-Konfig
- Welle-A-Inbox nutzt schon das `i18n/locales/{de,en}.json`-Schema für `nav.*`-Keys; das bleibt unverändert. Die Public-Page hatte bisher hardcoded DE — die kriegt jetzt ihre eigene Übersetzungs-Datei

**Hybrid-Workflow für die Übersetzung:** Xcode Auto-Translate als Erst-Vorschlag, Polish-Pass durch Dominik für Tauch-Vokabular und Tonalität.

**Public Card Page Language-Resolution:** Query-Param `?lang=` überschreibt Browser `Accept-Language`. Auto-Detect-Fallback auf DE wenn weder Param noch Accept-Match.

---

## 3. iOS Localization

### 3.1 String Catalog Setup

**Datei:** `apps/atollcard-native/AtollCard/Localizable.xcstrings`

Wird als Resource zum AtollCard-Target ergänzt in `project.yml`. Xcode 15+ findet Catalogs automatisch beim Build und extrahiert Keys aus dem Code.

**Widget-Target hat eigene Catalog:** `apps/atollcard-native/AtollCardWidget/Localizable.xcstrings` — Widget-Extensions können nicht auf App-Target-Resources zugreifen.

### 3.2 Was wird übersetzt

| Bereich | Strings | Beispiele |
|---|---|---|
| Cards-View | Section-Header, Stat-Labels | "Heute · Karten", "97 SCANS · 5 LEADS · DEFAULT" |
| Leads-Inbox | Status-Pille-Labels | "Neu", "Geöffnet", "Kontaktiert", "Importiert", "Archiviert", "Spam" |
| Lead-Detail | Action-Buttons | "Antworten", "Anrufen", "WhatsApp", "In Atoll Web öffnen", "Archivieren", "Als Spam" |
| Card-Editor | Form-Labels | "Titel", "Untertitel", "Badge", "Specialty hinzufügen", "Standard" |
| Settings | Section-Headers, Toggles | "Wallet", "NFC", "Default", "Theme", "Synchronisation", "Offline", "Sprache" |
| Wallet-Errors | localizedDescriptions | "Wallet im Mock-Modus nicht verfügbar", "Pass-Datei ist beschädigt" |
| Offline-UX | Banner + Badge | "Offline — Status-Änderungen werden synchronisiert sobald wieder verbunden" |
| Widget | LockScreenCardView | "Tippen → QR", "Karte einrichten" |
| Dead-Letter-View | Action-Buttons + Status | "Erneut versuchen", "Verwerfen", "Fehlgeschlagene Aktionen" |

**Nicht übersetzt (Daten, nicht UI):**
- Card-Title ("PADI Course Director" — DB-Daten)
- Lead-Daten (Email, Name, Message — User-Content)
- Specialty-Namen ("Deep Diver" — PADI-Standardbegriffe, bleiben EN)
- Datum (via `Date.formatted(date:time:)` System-auto-lokalisiert)

### 3.3 Sprachen-Picker in Settings

Settings-Section "Sprache" mit:

```
( ) System (Deutsch) ← default
( ) Deutsch
( ) English
( ) Français
```

Implementierung: `@AppStorage("preferredLanguage")` String mit Werten `nil` (= System), `"de"`, `"en"`, `"fr"`. Wenn nicht-nil: Bundle.main wird mit dem gewählten Locale überschrieben via `Locale.Components.preferredLanguage`.

Apple's offizieller Weg in iOS 17+: `UIApplication.openSettingsURLString` und User leitet in System-Settings die App-Sprache um. Für Pragmatik einfacher: in-App-Schalter via `Locale.Components`.

### 3.4 Hybrid-Workflow

1. **Code-Pass (Dominik mit Claude oder Sub-Agent):** alle hardcoded String-Literals in SwiftUI `Text("…")` durch lokalisierungs-fähige Form wandeln. Für SwiftUI-`Text` ist der Default schon localizable — der String wird Key im Catalog
2. **Xcode Build:** Catalog wird automatisch befüllt mit allen extrahierten Strings (DE als Source)
3. **Xcode Catalog UI:** `Editor → Translate Catalog with AI` für EN + FR
4. **Polish-Pass (Dominik):** Catalog durchgehen, manuelle Korrektur:
   - "Tarierung" → "Buoyancy" (nicht "Trim")
   - "Tauchgang" → "Dive" (nicht "Diving")
   - "Tauchgänge" → "Dives" (nicht "Plunges")
   - "Schüler" → "Student" (nicht "Pupil")
   - "Specialty" bleibt EN-Original auch im DE-Quellfile

---

## 4. Web Public Card Page Localization

### 4.1 Resolution-Logik

`apps/web/src/screens/PublicCardScreen.tsx` bekommt eine kleine Funktion:

```typescript
function resolveLanguage(searchParams: URLSearchParams): Lang {
  const param = searchParams.get('lang')?.toLowerCase()
  if (param === 'de' || param === 'en' || param === 'fr') return param

  const accept = navigator.language.split('-')[0]
  if (accept === 'en' || accept === 'fr') return accept
  return 'de'
}

type Lang = 'de' | 'en' | 'fr'
```

### 4.2 Translations-Map

Neue Datei `apps/web/src/screens/PublicCardScreen.i18n.ts`:

```typescript
type Lang = 'de' | 'en' | 'fr'

export const translations: Record<Lang, Record<string, string>> = {
  de: {
    addToContacts:      'Als Kontakt speichern',
    callMe:             'Anrufen',
    emailMe:            'E-Mail senden',
    whatsapp:           'WhatsApp',
    leadFormTitle:      'Anfrage schicken',
    leadFormFirstName:  'Vorname',
    leadFormLastName:   'Nachname',
    leadFormEmail:      'E-Mail',
    leadFormPhone:      'Telefon',
    leadFormTopic:      'Worum gehts?',
    leadFormMessage:    'Nachricht',
    leadFormSubmit:     'Senden',
    leadFormSending:    'Sende...',
    leadFormSuccess:    'Danke — ich melde mich!',
    leadFormError:      'Konnte nicht senden — bitte später nochmal versuchen.',
    notFoundTitle:      'Karte nicht gefunden',
    notFoundMessage:    'Diese Karte existiert nicht (mehr).',
  },
  en: {
    addToContacts:      'Save as contact',
    callMe:             'Call',
    emailMe:            'Email',
    whatsapp:           'WhatsApp',
    leadFormTitle:      'Get in touch',
    leadFormFirstName:  'First name',
    leadFormLastName:   'Last name',
    leadFormEmail:      'Email',
    leadFormPhone:      'Phone',
    leadFormTopic:      'About what?',
    leadFormMessage:    'Message',
    leadFormSubmit:     'Send',
    leadFormSending:    'Sending...',
    leadFormSuccess:    'Thanks — I will reach out!',
    leadFormError:      'Could not send — please try again later.',
    notFoundTitle:      'Card not found',
    notFoundMessage:    'This card does not exist (anymore).',
  },
  fr: {
    addToContacts:      'Enregistrer comme contact',
    callMe:             'Appeler',
    emailMe:            'E-mail',
    whatsapp:           'WhatsApp',
    leadFormTitle:      'Prendre contact',
    leadFormFirstName:  'Prénom',
    leadFormLastName:   'Nom',
    leadFormEmail:      'E-mail',
    leadFormPhone:      'Téléphone',
    leadFormTopic:      'À quel sujet ?',
    leadFormMessage:    'Message',
    leadFormSubmit:     'Envoyer',
    leadFormSending:    'Envoi...',
    leadFormSuccess:    'Merci — je vous contacte !',
    leadFormError:      'Impossible d\'envoyer — veuillez réessayer plus tard.',
    notFoundTitle:      'Carte introuvable',
    notFoundMessage:    'Cette carte n\'existe pas (plus).',
  },
}
```

### 4.3 LanguageSwitcher

`apps/web/src/components/LanguageSwitcher.tsx`:

Kleiner Dropdown/Globe-Icon top-right auf der PublicCardScreen. Aktive Sprache wird per `?lang=...` im URL geupdated, was via React-Router navigate ohne Reload triggert.

```tsx
function LanguageSwitcher({ current }: { current: Lang }) {
  const [searchParams, setSearchParams] = useSearchParams()
  function pick(lang: Lang) {
    setSearchParams(prev => {
      const next = new URLSearchParams(prev)
      next.set('lang', lang)
      return next
    })
  }
  return (
    <details style={{ position: 'absolute', top: 16, right: 16 }}>
      <summary>{labelFor(current)} ↓</summary>
      <button onClick={() => pick('de')}>Deutsch</button>
      <button onClick={() => pick('en')}>English</button>
      <button onClick={() => pick('fr')}>Français</button>
    </details>
  )
}
```

### 4.4 Was in PublicCardScreen geändert wird

Alle hardcoded DE-Strings in `apps/web/src/screens/PublicCardScreen.tsx` durch `t.<key>` ersetzen, wo `t = translations[lang]`. LanguageSwitcher oben rechts einbauen.

---

## 5. File-Inventar

### Neu

```
apps/atollcard-native/AtollCard/
└── Localizable.xcstrings                              iOS String Catalog (DE source, EN+FR translated)

apps/atollcard-native/AtollCardWidget/
└── Localizable.xcstrings                              Widget String Catalog

apps/web/src/
├── screens/
│   └── PublicCardScreen.i18n.ts                       translations map (DE/EN/FR)
└── components/
    └── LanguageSwitcher.tsx                           dropdown DE/EN/FR

docs/superpowers/runbooks/
└── 2026-05-26-atollcard-localization-welle-e-rollout.md
```

### Geändert

```
apps/atollcard-native/
├── project.yml                                        + Localizable.xcstrings als Resource (beide Targets)
├── AtollCard/                                         alle hardcoded String-Literals durch
│   ├── Views/...                                      Text("…") / String(localized: "…") /
│   │                                                  NSLocalizedString-Pattern ersetzen
│   ├── Services/WalletPassService.swift               WalletPassError.errorDescription Strings
│   ├── Services/MutationDrainer.swift                 wenn user-facing Strings drin sind
│   └── Repositories/...                               wenn user-facing Strings drin sind
├── AtollCardWidget/LockScreenCardView.swift           Widget-Strings lokalisieren
└── CHANGELOG.md                                       + 0.13.0 Entry

apps/web/src/
└── screens/PublicCardScreen.tsx                       resolveLanguage + LanguageSwitcher + t.* überall
```

### Test-Coverage

- **iOS:** keine extra-Tests in dieser Welle. Snapshot-Tests bleiben DE-only (gemäss heute). Locale-Manual-Test im Runbook
- **Web:** Bestehende Component-Tests bleiben unverändert (sie asserten auf testIDs, nicht auf Strings). Plus manueller Test mit `?lang=en` und `?lang=fr` im Browser

---

## 6. Rollout-Plan

1. **iOS Code-Pass:** alle hardcoded `Text("…")`-Literals durchgehen, Catalog-keys lassen (oder explizit als `Text("Heute", comment: "…")` taggen)
2. **Xcode Build:** Catalog wird automatisch befüllt mit DE
3. **Xcode UI:** Catalog auswählen → Translate-Action für EN + FR → ML-translations werden eingefügt
4. **Dominik Polish-Pass:** Tauch-Vokabular fixen, Tonalität korrigieren
5. **Widget-Catalog analog** (~5 Strings)
6. **Web:** `PublicCardScreen.i18n.ts` schreiben (alle 3 Sprachen manuell)
7. **Web:** `LanguageSwitcher` Component schreiben
8. **Web:** `PublicCardScreen.tsx` umbauen mit `resolveLanguage()` + `t.*`
9. **iOS-Build aufs iPhone, Locale-Toggle in Settings testen**
10. **Web:** `npm run dev`, `?lang=en` und `?lang=fr` testen + LanguageSwitcher klicken

---

## 7. Out-of-Scope

- **Card-Daten mehrsprachig** (Card.title in 3 Sprachen) — Schema-Change, separates Sub-Projekt
- **Web-Inbox / Adressbuch i18n** (Frage 1 B → DE only)
- **PADI-Specialty-Namen** — EN-Original-Pflicht
- **APNs-Push-Body lokalisieren** — Server-side, separate Edge-Function-Anpassung
- **RTL-Support** — keine Use Case
- **Brand-Voice-Konsistenz EN/FR** — eigene writing-rules in EN/FR wäre Welle-X
- **`?lang=` Param in iOS-Deep-Link** (`/contacts/card-inbox?lead=<id>&lang=en`) — Web-Inbox ist DE only, kein Bedarf

---

## 8. Open Risiken & Annahmen

1. **Xcode Auto-Translate Qualität für Tauch-Vokabular** — Polish-Pass unentbehrlich
2. **iOS in-App Language-Override mit `Locale.Components`** — Apple-Patterns für iOS 17+ sind divergierend; falls Bundle-Override nicht funktioniert, Fallback auf `UIApplication.openSettingsURLString` mit User-System-Locale-Wechsel
3. **LanguageSwitcher Mobile-Footprint** — Globe-Icon variante statt Dropdown-Text für Mobile
4. **`?lang=` URL-Persistenz** — wenn User innerhalb der Page navigiert (z.B. Modal öffnet), bleibt der Param im URL erhalten via React-Router
5. **Card-Daten bleiben DE** — User mit EN-Locale sieht "PADI Course Director" auf der Card-Front, was OK ist (PADI-Termini sind eh EN). Aber "Tauch-Profil" o.ä. DB-Texte würden komisch wirken wenn vorhanden — heute nicht der Fall
6. **First-launch-Locale-Detection** in iOS: System-Locale wird direkt von `Locale.current` gelesen — funktioniert "out of the box". Keine extra-Logik nötig

---

## 9. Akzeptanzkriterien

- [ ] iOS-App auf System-Locale=EN: alle UI-Chrome-Strings sind EN
- [ ] iOS-App auf System-Locale=FR: alle UI-Chrome-Strings sind FR
- [ ] iOS-Widget zeigt EN/FR-Strings entsprechend Locale
- [ ] iOS Settings → Sprache überschreibt System-Default
- [ ] Web `?lang=de`: Public-Page rendert DE
- [ ] Web `?lang=en`: Public-Page rendert EN
- [ ] Web `?lang=fr`: Public-Page rendert FR
- [ ] Web ohne Query + Browser-Locale=EN: Page rendert EN
- [ ] Web LanguageSwitcher schaltet zur Laufzeit
- [ ] Lead-Form Submit funktioniert in allen 3 Sprachen (Submit-Button-Text wechselt)
- [ ] vCard-Generierung (Save as contact) funktioniert in allen 3 Sprachen
- [ ] Card-Daten bleiben DE (Titel, Specialties) — UI-Chrome ist übersetzt

---

## 10. Referenzen

- [Apple String Catalog Documentation](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)
- [SwiftUI Text(_:) localized initializer](https://developer.apple.com/documentation/swiftui/text)
- Existing `apps/web/src/i18n/locales/{de,en}.json` (Welle A) — Pattern für statische Übersetzungen
- AtollCard `ABOUT ME/writing-rules.de.md` — Tonalitäts-Referenz für DE-Source
- Welle-A `PublicCardScreen.tsx` — die Datei die übersetzt wird
