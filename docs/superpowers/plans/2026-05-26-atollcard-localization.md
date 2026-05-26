# AtollCard Localization (DE/EN/FR) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** iOS-App (inkl. Widget) + Web Public-Card-Page sprechen DE/EN/FR. iOS via String Catalog, Web via kleine TS-Translations-Map mit `?lang=`-Override.

**Architecture:** Xcode `.xcstrings` für iOS (auto-extracted from `Text("…")` literals; Hybrid-Workflow ML-Auto-Translate + manueller Polish-Pass). Web: einmalige TS-Map mit ~20 Keys, `resolveLanguage()`-Funktion mit URL-Param-Override + Accept-Language-Fallback, LanguageSwitcher-Dropdown.

**Tech Stack:** Swift 6 + SwiftUI + Xcode String Catalog + React + react-router-dom.

**Spec:** `docs/superpowers/specs/2026-05-26-atollcard-localization-design.md`

---

## Phase A — Web Public-Card-Page i18n

### Task 1: `PublicCardScreen.i18n.ts` Translations-Map

**Files:**
- Create: `apps/web/src/screens/PublicCardScreen.i18n.ts`

- [ ] **Step 1: Translations-Map schreiben**

Inhalt von `apps/web/src/screens/PublicCardScreen.i18n.ts`:

```typescript
/**
 * Translations for the public card page (PublicCardScreen).
 * Only UI chrome is translated — card data (title, specialties, owner name)
 * stays in the source language (DE).
 */

export type Lang = 'de' | 'en' | 'fr'

export const SUPPORTED_LANGS: readonly Lang[] = ['de', 'en', 'fr'] as const

export interface Translations {
  addToContacts:      string
  callMe:             string
  emailMe:            string
  whatsapp:           string
  leadFormTitle:      string
  leadFormFirstName:  string
  leadFormLastName:   string
  leadFormEmail:      string
  leadFormPhone:      string
  leadFormTopic:      string
  leadFormMessage:    string
  leadFormSubmit:     string
  leadFormSending:    string
  leadFormSuccess:    string
  leadFormError:      string
  notFoundTitle:      string
  notFoundMessage:    string
  languageLabel:      string
}

export const translations: Record<Lang, Translations> = {
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
    languageLabel:      'Sprache',
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
    languageLabel:      'Language',
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
    leadFormError:      "Impossible d'envoyer — veuillez réessayer plus tard.",
    notFoundTitle:      'Carte introuvable',
    notFoundMessage:    "Cette carte n'existe pas (plus).",
    languageLabel:      'Langue',
  },
}

/**
 * Resolve the page language from URL params + browser Accept-Language.
 * Priority: ?lang= param > navigator.language > 'de' fallback.
 */
export function resolveLanguage(searchParams: URLSearchParams): Lang {
  const param = searchParams.get('lang')?.toLowerCase()
  if (param === 'de' || param === 'en' || param === 'fr') return param

  const accept = navigator.language.split('-')[0].toLowerCase()
  if (accept === 'en' || accept === 'fr') return accept

  return 'de'
}
```

- [ ] **Step 2: Commit**

```bash
git add apps/web/src/screens/PublicCardScreen.i18n.ts
git commit -m "feat(i18n): PublicCardScreen translations + resolveLanguage helper"
```

---

### Task 2: `LanguageSwitcher` Component

**Files:**
- Create: `apps/web/src/components/LanguageSwitcher.tsx`

- [ ] **Step 1: Component schreiben**

Inhalt von `apps/web/src/components/LanguageSwitcher.tsx`:

```typescript
import { useSearchParams } from 'react-router-dom'
import type { Lang } from '@/screens/PublicCardScreen.i18n'

interface Props {
  current: Lang
}

const LABELS: Record<Lang, string> = {
  de: 'Deutsch',
  en: 'English',
  fr: 'Français',
}

/**
 * Tiny dropdown to switch the page language via ?lang= query param.
 * Used on PublicCardScreen — the only multilingual screen in the web app.
 */
export function LanguageSwitcher({ current }: Props) {
  const [searchParams, setSearchParams] = useSearchParams()

  function pick(lang: Lang) {
    setSearchParams((prev) => {
      const next = new URLSearchParams(prev)
      next.set('lang', lang)
      return next
    }, { replace: true })
  }

  return (
    <details
      style={{
        position: 'absolute',
        top: 16,
        right: 16,
        zIndex: 10,
      }}
    >
      <summary
        style={{
          listStyle: 'none',
          cursor: 'pointer',
          padding: '6px 10px',
          background: 'rgba(0,0,0,0.04)',
          border: '1px solid rgba(0,0,0,0.08)',
          borderRadius: 8,
          fontSize: 13,
          userSelect: 'none',
        }}
      >
        🌐 {LABELS[current]}
      </summary>
      <div
        style={{
          marginTop: 4,
          background: 'white',
          border: '1px solid rgba(0,0,0,0.1)',
          borderRadius: 8,
          boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
          minWidth: 140,
        }}
      >
        {(['de', 'en', 'fr'] as const).map((lang) => (
          <button
            key={lang}
            type="button"
            onClick={() => pick(lang)}
            style={{
              display: 'block',
              width: '100%',
              padding: '8px 12px',
              background: lang === current ? 'rgba(0,0,0,0.04)' : 'transparent',
              border: 'none',
              cursor: 'pointer',
              textAlign: 'left',
              fontSize: 13,
              fontWeight: lang === current ? 600 : 400,
            }}
          >
            {LABELS[lang]}
          </button>
        ))}
      </div>
    </details>
  )
}
```

- [ ] **Step 2: Commit**

```bash
git add apps/web/src/components/LanguageSwitcher.tsx
git commit -m "feat(i18n): LanguageSwitcher dropdown component"
```

---

### Task 3: `PublicCardScreen.tsx` mit `t.*` und Switcher umbauen

**Files:**
- Modify: `apps/web/src/screens/PublicCardScreen.tsx`

- [ ] **Step 1: Heutige hardcoded DE-Strings finden**

```bash
grep -nE '"(Anrufen|Senden|Anfrage|Vorname|Nachricht|E-Mail|Karte nicht gefunden|Als Kontakt|Danke|Konnte nicht senden)"' apps/web/src/screens/PublicCardScreen.tsx | head -20
```

Liste der Stellen — alle durch `t.<key>` ersetzen.

- [ ] **Step 2: Imports + State + Render-Anpassung**

Im File-Header `PublicCardScreen.tsx`:

```typescript
import { useSearchParams } from 'react-router-dom'
import { translations, resolveLanguage, type Lang } from './PublicCardScreen.i18n'
import { LanguageSwitcher } from '@/components/LanguageSwitcher'
```

Im Component-Body, gleich am Anfang:

```typescript
export function PublicCardScreen() {
  const [searchParams] = useSearchParams()
  const lang: Lang = resolveLanguage(searchParams)
  const t = translations[lang]
  // … existing logic
}
```

Im JSX-Return, ganz aussen vor dem Card-Block (oder am Top des Containers):

```tsx
  <LanguageSwitcher current={lang} />
```

Alle hardcoded DE-Strings im JSX durch `{t.fieldName}` ersetzen. Z.B.:
- `<button>Anrufen</button>` → `<button>{t.callMe}</button>`
- `<input placeholder="E-Mail" />` → `<input placeholder={t.leadFormEmail} />`
- `<h2>Anfrage schicken</h2>` → `<h2>{t.leadFormTitle}</h2>`

Submit-Loading: `<button>{isSubmitting ? t.leadFormSending : t.leadFormSubmit}</button>`

Success-State: ersetzt durch `<p>{t.leadFormSuccess}</p>`

Error-State: `<p>{t.leadFormError}</p>`

Not-Found-State (falls vorhanden): `<h1>{t.notFoundTitle}</h1>` und `<p>{t.notFoundMessage}</p>`

vCard "Save as contact"-Button: `<button>{t.addToContacts}</button>`

- [ ] **Step 3: Build-Check**

```bash
cd apps/web
npm run build 2>&1 | tail -10
```

Expected: grün — keine TS-Errors.

- [ ] **Step 4: Manueller Smoke**

```bash
npm run dev
```

Browser:
- `http://localhost:5173/c/dominik-cd` — sollte DE rendern (Browser-Default vermutlich DE)
- `http://localhost:5173/c/dominik-cd?lang=en` — EN
- `http://localhost:5173/c/dominik-cd?lang=fr` — FR
- LanguageSwitcher oben rechts → klick zwischen Sprachen, Page-Inhalt switcht

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/screens/PublicCardScreen.tsx
git commit -m "feat(i18n): PublicCardScreen — resolveLanguage + t.* + LanguageSwitcher"
```

---

## Phase B — iOS String Catalog

### Task 4: `Localizable.xcstrings` Catalog für AtollCard-Target anlegen

**Files:**
- Create: `apps/atollcard-native/AtollCard/Localizable.xcstrings`
- Modify: `apps/atollcard-native/project.yml`

- [ ] **Step 1: String Catalog-File anlegen**

Das `.xcstrings`-Format ist ein JSON-Schema von Apple. Initial-Inhalt (leerer Catalog mit DE als Source):

```json
{
  "sourceLanguage" : "de",
  "strings" : { },
  "version" : "1.0"
}
```

`apps/atollcard-native/AtollCard/Localizable.xcstrings`:

```json
{
  "sourceLanguage" : "de",
  "strings" : { },
  "version" : "1.0"
}
```

- [ ] **Step 2: `project.yml` aktualisieren**

Im `project.yml` AtollCard-Target `sources:` ergänzen wenn `AtollCard` als Pfad reicht — der Catalog liegt unter `AtollCard/Localizable.xcstrings`, sollte automatisch eingezogen werden. Falls explicit-list nötig, ergänzen:

```yaml
    sources:
      - AtollCard
      - AtollCardShared
```

(Plan-Annahme: existing source-pattern picks up the file automatically.)

- [ ] **Step 3: Commit**

```bash
git add apps/atollcard-native/AtollCard/Localizable.xcstrings \
        apps/atollcard-native/project.yml
git commit -m "feat(i18n-ios): empty Localizable.xcstrings catalog (source: de)"
```

---

### Task 5: iOS Code-Pass — Strings als lokalisierbar markieren

**Files:**
- Modify: alle Files in `apps/atollcard-native/AtollCard/Views/` und ggf. `apps/atollcard-native/AtollCard/Services/` mit user-facing Strings

- [ ] **Step 1: Code-Stellen finden**

```bash
grep -rnE '\bText\("[^"]+"\)' apps/atollcard-native/AtollCard/Views/ | head -30
```

SwiftUI `Text("Hallo")` ist **schon** standard-mässig localizable — der String wird Catalog-Key. **Kein Code-Change nötig** für `Text(...)`.

**Was Code-Pass braucht:**

1. **String literals außerhalb von `Text(...)`** — z.B. in `.alert(title:)`, `Button("…", action: ...)`, Form-Field-Labels — müssen via `String(localized: "…")` gewrappt werden, sonst extrahiert Xcode sie nicht.
2. **Error-Descriptions** (z.B. `WalletPassError.errorDescription`) — die Strings im switch dort durch `String(localized: "…")` wrappen.

Beispiel-Edit in `WalletPassService.swift`:

```swift
// Vorher:
public var errorDescription: String? {
  switch self {
  case .unavailable: "Apple Wallet ist auf diesem Gerät nicht verfügbar."
  // …
  }
}

// Nachher:
public var errorDescription: String? {
  switch self {
  case .unavailable: String(localized: "Apple Wallet ist auf diesem Gerät nicht verfügbar.")
  // …
  }
}
```

Mache das für alle user-facing Strings ausserhalb von `Text(...)`. Übersicht der Stellen:

```bash
grep -rnE 'errorDescription|Button\("[^"]+"|\.alert\(|TextField\(' apps/atollcard-native/AtollCard/ | head -40
```

- [ ] **Step 2: Xcode Build → Auto-Populate**

```bash
cd apps/atollcard-native
xcodegen generate
open AtollCard.xcodeproj
```

Build (Cmd+B). Xcode extrahiert alle `Text(...)` und `String(localized: ...)`-Keys in den Catalog. Re-open `Localizable.xcstrings` im Xcode — sollte jetzt ~50-100 Keys auflisten mit DE-Source-Texten.

- [ ] **Step 3: Commit**

```bash
git add apps/atollcard-native/AtollCard/ apps/atollcard-native/AtollCard/Localizable.xcstrings
git commit -m "feat(i18n-ios): wrap non-Text user-facing strings with String(localized:)"
```

---

### Task 6: Xcode Auto-Translate für EN + FR

**Files:**
- Modify: `apps/atollcard-native/AtollCard/Localizable.xcstrings` (Xcode-UI-driven, kein direkter Code-Edit)

- [ ] **Step 1: In Xcode den Catalog öffnen**

In Xcode-Sidebar `Localizable.xcstrings` doppelklicken. Catalog-UI zeigt eine Tabelle: Key | DE (Source) | EN | FR (beide leer).

- [ ] **Step 2: Sprachen-Spalten hinzufügen**

Oben links im Catalog-Editor `+`-Button → "English" + "French" hinzufügen.

- [ ] **Step 3: Auto-Translate triggern**

`Editor → Translate Catalog with AI` (oder Rechtsklick auf Key-Spalte). Xcode wählt alle Keys → ML-Übersetzung wird eingefügt.

- [ ] **Step 4: Speichern, kein Commit (kommt nach Polish)**

Xcode schreibt den Catalog automatisch raus.

(Dieser Task ist UI-driven — kein Commit-Step. Wird mit Task 7 zusammen committet.)

---

### Task 7: Polish-Pass — Tauch-Vokabular fixen

**Files:**
- Modify: `apps/atollcard-native/AtollCard/Localizable.xcstrings`

- [ ] **Step 1: Catalog im Xcode durchgehen**

Pro Key alle 3 Sprachen prüfen. Hauptkorrekturen die zu erwarten sind:

| DE | EN auto | EN korrigiert | FR auto | FR korrigiert |
|---|---|---|---|---|
| Tarierung | Trim | Buoyancy | Tassement | Stabilisation |
| Tauchgang | Diving | Dive | Plongée | Plongée ✓ |
| Tauchgänge | Plunges | Dives | Plongées | Plongées ✓ |
| Schüler | Pupil | Student | Élève | Élève ✓ |
| Tauchlehrer | Diving Teacher | Instructor | Moniteur | Moniteur ✓ |
| Tieftauchgang | Deep dive | Deep dive ✓ | Plongée profonde | Plongée profonde ✓ |
| Specialty | Specialty (bleibt) | Specialty ✓ | Spécialité | Spécialité ✓ |
| Anfrage | Inquiry | Request | Demande | Demande ✓ |
| Sende... | Sending... | Sending... ✓ | Envoi... | Envoi... ✓ |
| Antworten | Answer | Reply | Répondre | Répondre ✓ |

(Polish ist iterativ — Dominik geht alle Keys 1× durch, fixt was komisch ist, andere lassen wie sie sind.)

- [ ] **Step 2: Catalog speichern + commit**

```bash
git add apps/atollcard-native/AtollCard/Localizable.xcstrings
git commit -m "feat(i18n-ios): EN+FR translations (auto-translate + polish for diving terms)"
```

---

### Task 8: Settings → Sprache Picker

**Files:**
- Modify: `apps/atollcard-native/AtollCard/Views/Settings/SettingsView.swift`

- [ ] **Step 1: Picker einbauen**

In `SettingsView.swift` eine neue Section ergänzen:

```swift
@AppStorage("preferredLanguage") private var preferredLanguage: String = ""

Section(String(localized: "Sprache")) {
  Picker(String(localized: "Sprache"), selection: $preferredLanguage) {
    Text(String(localized: "System")).tag("")
    Text("Deutsch").tag("de")
    Text("English").tag("en")
    Text("Français").tag("fr")
  }
  .onChange(of: preferredLanguage) { _, newValue in
    if newValue.isEmpty {
      UserDefaults.standard.removeObject(forKey: "AppleLanguages")
    } else {
      UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
    }
    UserDefaults.standard.synchronize()
    // Apple recommendation: require restart for full effect.
    // For instant-effect, you'd need to rebuild the View tree, which is overkill.
  }
}
```

Plus einen kleinen Hinweis-Text unter dem Picker:

```swift
Text(String(localized: "Sprache-Wechsel wird beim nächsten App-Start aktiv."))
  .font(.system(size: 11))
  .foregroundStyle(.secondary)
```

- [ ] **Step 2: Commit**

```bash
git add apps/atollcard-native/AtollCard/Views/Settings/SettingsView.swift
git commit -m "feat(i18n-ios): Settings → Sprache picker (System/DE/EN/FR)"
```

---

## Phase C — Widget Catalog

### Task 9: Widget Localization

**Files:**
- Create: `apps/atollcard-native/AtollCardWidget/Localizable.xcstrings`
- Modify: `apps/atollcard-native/AtollCardWidget/LockScreenCardView.swift`
- Modify: `apps/atollcard-native/project.yml` (falls explicit-list)

- [ ] **Step 1: Widget Catalog anlegen**

Inhalt von `apps/atollcard-native/AtollCardWidget/Localizable.xcstrings`:

```json
{
  "sourceLanguage" : "de",
  "strings" : { },
  "version" : "1.0"
}
```

- [ ] **Step 2: Widget-Strings markieren**

In `LockScreenCardView.swift` die String-Literals lokalisierungs-fähig machen. Beispiel der heutigen Zeile:

```swift
// Vorher:
Text("Tippen → QR")

// Nachher:
Text(String(localized: "Tippen → QR", bundle: .main))
```

(Widget-Extension hat eigene Bundle — explizite `bundle: .module` falls eigenes Module, sonst `.main` wenn das Catalog im Widget-Target-Bundle ist.)

Analog für:
- `Text("AtollCard")` (im Fallback-Block)
- `Text("Karte einrichten")`

`configurationDisplayName` und `description` im Widget-config:

```swift
.configurationDisplayName(String(localized: "AtollCard Quick-QR"))
.description(String(localized: "Default-Karte mit One-Tap zum Vollbild-QR."))
```

- [ ] **Step 3: Xcode Build → Auto-Populate + Auto-Translate**

Selbes Pattern wie Task 6/7: Xcode öffnet `AtollCardWidget/Localizable.xcstrings`, EN/FR Spalten hinzufügen, Auto-Translate, Polish-Pass (~5 Strings, sehr schnell).

- [ ] **Step 4: Commit**

```bash
git add apps/atollcard-native/AtollCardWidget/Localizable.xcstrings \
        apps/atollcard-native/AtollCardWidget/LockScreenCardView.swift \
        apps/atollcard-native/project.yml
git commit -m "feat(i18n-widget): String Catalog + localized strings"
```

---

## Phase D — Rollout

### Task 10: Runbook + CHANGELOG 0.13.0

**Files:**
- Create: `docs/superpowers/runbooks/2026-05-26-atollcard-localization-welle-e-rollout.md`
- Modify: `apps/atollcard-native/CHANGELOG.md`

- [ ] **Step 1: Runbook**

Inhalt von `docs/superpowers/runbooks/2026-05-26-atollcard-localization-welle-e-rollout.md`:

```markdown
# Runbook: AtollCard Localization DE/EN/FR (Welle E)

**Spec:** `docs/superpowers/specs/2026-05-26-atollcard-localization-design.md`
**Plan:** `docs/superpowers/plans/2026-05-26-atollcard-localization.md`

## Pre-Implementation

- [ ] Branch `feat/atollcard-localization` ausgecheckt
- [ ] Voherige Wellen A-D auf main

## Code-Deploy

- [ ] `xcodegen generate` im `apps/atollcard-native/`
- [ ] Xcode öffnen, Catalog auswählen → EN/FR Sprachen hinzufügen, Auto-Translate, Polish-Pass
- [ ] iOS Cmd+B sollte clean durchgehen
- [ ] Web: `npm run build` im `apps/web/` — sollte clean

## Manueller iOS-Test

- [ ] App auf iPhone, System-Locale auf English stellen (iOS Einstellungen → Allgemein → Sprache & Region → English)
- [ ] AtollCard öffnen — alle UI-Strings EN
- [ ] Auf French wechseln — alle UI-Strings FR
- [ ] Zurück auf Deutsch
- [ ] Widget am Lock-Screen prüfen — "Tippen → QR" / "Tap → QR" / "Taper → QR" je nach Locale

## Manueller iOS Settings-Override-Test

- [ ] System-Locale Deutsch
- [ ] App → Settings → Sprache → English
- [ ] App neu starten — alle Strings EN obwohl System DE

## Manueller Web-Test

- [ ] `npm run dev`
- [ ] `http://localhost:5173/c/dominik-cd` — sollte mit Browser-Locale rendern
- [ ] `?lang=en` — EN
- [ ] `?lang=fr` — FR
- [ ] LanguageSwitcher oben rechts → durchklicken
- [ ] Lead-Form ausfüllen + senden — alle Labels EN, Success-Message EN
- [ ] vCard "Save as contact" funktioniert in EN

## Rollback

Wenn etwas bricht:
- iOS: Bundle-Override für `AppleLanguages` entfernen via `UserDefaults.standard.removeObject(forKey: "AppleLanguages")`. App neu starten, fällt zurück auf System
- Web: `?lang=`-Param ignorieren in der URL → Browser-Default greift
```

- [ ] **Step 2: CHANGELOG**

Im `apps/atollcard-native/CHANGELOG.md` oben über dem Top-Eintrag (0.12.0):

```markdown
## 0.13.0 — Localization DE/EN/FR (Larry, 26.05.2026)

iOS-App + Widget + Web Public-Card-Page sprechen jetzt DE/EN/FR.

### iOS

- `Localizable.xcstrings` String Catalog im AtollCard-Target
- `Localizable.xcstrings` String Catalog im Widget-Target
- Settings → Sprache Picker (System / DE / EN / FR)
- Hybrid-Workflow: Xcode Auto-Translate + Polish-Pass für Tauch-Vokabular

### Web

- `PublicCardScreen.i18n.ts` Translations-Map mit ~20 Keys
- `resolveLanguage()` mit `?lang=`-Param-Override + Browser-Accept-Language-Fallback
- LanguageSwitcher Dropdown auf der Public-Page

### Out-of-Scope

- Web-Inbox + Adressbuch bleiben DE only (User-Basis ist Dominik)
- Card-Daten (Titel, Specialties) bleiben einsprachig — nur UI-Chrome ist lokalisiert
- APNs-Push-Body-Text nicht lokalisiert (Server-side, separates Sub-Projekt)
```

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/runbooks/2026-05-26-atollcard-localization-welle-e-rollout.md \
        apps/atollcard-native/CHANGELOG.md
git commit -m "docs: localization rollout runbook + AtollCard 0.13.0 changelog"
```

---

## Self-Review-Checklist (post-hoc)

**Spec-Coverage:**
- §3 iOS String Catalog → Tasks 4, 5, 6, 7 ✓
- §3.3 Sprachen-Picker → Task 8 ✓
- §4 Web Public-Page → Tasks 1, 2, 3 ✓
- §5 File-Inventar → über alle Tasks ✓
- §6 Rollout → Task 10 ✓
- §9 Akzeptanzkriterien → durch Runbook-Manual-Tests abgedeckt ✓

**Placeholder-Scan:** keine TBD/TODO/FIXME im Plan. Tasks 6 + 7 sind bewusst UI-driven (Xcode-Catalog-UI), kein Code-Snippet möglich.

**Typkonsistenz:**
- `Lang` als `'de' | 'en' | 'fr'` durchgängig in Tasks 1, 2, 3
- `translations[lang]` Pattern in Task 1 + 3
- `String(localized: "…")` Pattern in Tasks 5, 8, 9

**Bekannte Follow-ups:**
- Brand-Voice-Konsistenz für EN/FR (eigene writing-rules) — out of scope
- Server-side Push-Body Lokalisierung — Welle B-Folge
- Card-Daten mehrsprachig (DB-Schema) — Schema-Change-Sub-Projekt
