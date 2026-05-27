# AtollCard

Digitale Visitenkarten + Lead-Capture für Atoll OS. iOS-App, geschrieben in Swift 6 / SwiftUI, läuft Side-by-Side mit AtollCal im selben Monorepo.

## Quick start

```bash
# Im Repo-Root (Dispo/):
brew install xcodegen          # falls noch nicht da
cd apps/atollcard-native
xcodegen generate              # erzeugt AtollCard.xcodeproj
open AtollCard.xcodeproj
```

Beim ersten Öffnen in Xcode:
1. **Signing & Capabilities → Team:** `XK8V89P2QV` ist bereits gesetzt — falls Xcode meckert, einmal manuell durchklicken.
2. **Run** auf "iPhone 15 Pro" (oder echtes Gerät — NFC + Wallet brauchen Hardware).

Die App startet mit **Mock-Daten** (3 Karten, ~8 Leads, synthetisierte Analytics). Du musst nichts konfigurieren um sie funktionsfähig zu sehen. Sobald Supabase fertig ist, in `Config.swift` `useMockData = false` setzen.

## Architektur

* **SwiftUI + @Observable** (Swift 6 strict concurrency, iOS 26 — siehe Annahme #1)
* **Repository-Pattern**: `CardRepository` / `LeadRepository` / `AnalyticsRepository` sind Protocols. Aktuell läuft alles gegen die `Mock*Repository`-Varianten; die `Supabase*Repository`-Klassen sind Stubs und werfen `RepositoryError.notImplemented`, bis das Schema steht.
* **@Observable Stores** (`CardStore`, `LeadStore`, `AnalyticsStore`) injizieren das Repository und halten den UI-State.
* **Shared Packages**: nutzt `AtollCore` (Auth, Supabase-Client) und `AtollDesign` (Brand-Farben, Avatar) aus `../../swift-packages/`. Keine Duplikate.
* **Feature-Folder**: `Models/`, `Repositories/`, `Services/`, `Theme/`, `Views/Cards|Leads|Analytics|Settings|Share|Components/`.

Siehe `CHANGELOG.md` für die ausführliche Begründung jeder grossen Entscheidung.

## Supabase Setup — von Mock auf live

Schritt-für-Schritt:

### 1. Migration anwenden

Die SQL-Migration liegt im Monorepo bei den anderen Atoll-Migrations:
```
~/Desktop/Developer/Dispo/supabase/migrations/0097_atollcard_schema.sql
```

Sie legt 4 Tabellen an (`cards`, `card_scans`, `card_leads`, `nfc_tags`), 5 Enums, die nötigen Indexes, einen `updated_at`-Trigger und RLS-Policies. Owner-Modell: `cards.person_id → contacts.id`, RLS via `contact_instructor.auth_user_id = auth.uid()`.

**Apply:**
- Mit Supabase CLI: `supabase db push` im Monorepo-Root (wenn die CLI verlinkt ist), oder
- Manuell: Inhalt der SQL-Datei in den Supabase Dashboard SQL Editor kopieren → Run

### 2. Erste Karte anlegen (SQL, einmalig)

Da RLS scharf ist, brauchst du eine erste Karte über den Service-Role-Key oder direkt im Dashboard. Beispiel-Insert für Dominiks CD-Karte (ersetze die Contact-ID):

```sql
INSERT INTO public.cards (person_id, slug, title, subtitle, badge, theme, dive_profile, is_default)
VALUES (
  (SELECT id FROM contacts WHERE primary_email = 'weckherlin@icloud.com'),
  'dominik-cd',
  'PADI Course Director',
  '#226710',
  'PADI CD',
  '{"preset":"courseDirector"}'::jsonb,
  '{"padi_member_number":"226710","instructor_level":"CD","specialties":["Deep","Nitrox","Wreck"],"total_dives":7800,"since_year":2008,"teaching_languages":["DE","EN","FR"]}'::jsonb,
  true
);
```

### 3. Mock-Mode ausschalten

In `AtollCard/Config.swift`:
```swift
static let useMockData = false
```

### 4. App neu starten

- Magic-Link-Login per E-Mail
- `cards`-Tabelle wird via `SupabaseCardRepository.fetchAll()` geladen
- Die Karten zeigen jetzt deine echten Daten statt Dominik-Mock

### 5. Supabase Auth Redirect URL whitelisten

Im Supabase Dashboard → Authentication → URL Configuration → Redirect URLs:
* `atollcard://auth/callback` hinzufügen
* `Site URL`: `https://atoll-os.com` (für die Public-Card-Page)

Damit funktioniert der Magic Link in der Email und springt zurück in die App.

## Supabase-Schema — Tabellen-Referenz

Alle Details der erwarteten Tabellen:

### `cards`
```sql
create table public.cards (
  id          uuid primary key default gen_random_uuid(),
  person_id   uuid not null references public.persons(id) on delete cascade,
  slug        text not null unique,
  title       text not null,
  subtitle    text,
  badge       text,
  theme       jsonb not null default '{"preset":"courseDirector"}'::jsonb,
  field_visibility jsonb not null default '{}'::jsonb,
  dive_profile     jsonb,
  is_default  boolean not null default false,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index on public.cards (person_id);
```

### `card_scans`
```sql
create table public.card_scans (
  id           uuid primary key default gen_random_uuid(),
  card_id      uuid not null references public.cards(id) on delete cascade,
  scanned_at   timestamptz not null default now(),
  source       text not null check (source in ('qr','nfc','airdrop','imessage','wallet','direct')),
  ip_country   text,
  user_agent   text,
  converted_to_lead boolean not null default false,
  field_tapped text
);
create index on public.card_scans (card_id, scanned_at desc);
```

### `card_leads`
```sql
create table public.card_leads (
  id            uuid primary key default gen_random_uuid(),
  card_id       uuid not null references public.cards(id) on delete cascade,
  first_name    text not null,
  last_name     text,
  email         text,
  phone         text,
  message       text,
  topic         text,
  custom_answers jsonb not null default '{}'::jsonb,
  captured_at   timestamptz not null default now(),
  ip_country    text,
  imported_to_address_book boolean not null default false,
  status        text not null default 'new'
                  check (status in ('new','opened','contacted','imported','archived','spam')),
  avatar_color  text
);
create index on public.card_leads (card_id, captured_at desc);
```

### `nfc_tags`
```sql
create table public.nfc_tags (
  id          uuid primary key default gen_random_uuid(),
  card_id     uuid not null references public.cards(id) on delete cascade,
  tag_uid     text not null,
  label       text,
  written_at  timestamptz not null default now(),
  last_seen_at timestamptz
);
create unique index on public.nfc_tags (tag_uid);
```

### `card_dive_profiles` (optional — kann auch im `cards.dive_profile` jsonb-Feld leben)
Aktuell embeddet AtollCard das Dive-Profil **inline in `cards.dive_profile`** als jsonb (siehe `DiveProfile.swift`). Falls du es separat ausziehen willst, mach eine eigene Tabelle mit denselben Spalten und joine im PostgREST-View.

### RLS Policies (Skizze)
```sql
alter table public.cards enable row level security;
create policy "own cards" on public.cards for all using (
  person_id in (select id from public.persons where auth_user_id = auth.uid())
);
-- Analog für card_scans, card_leads, nfc_tags via cards-Lookup.
```

## Apple-Developer-Konfiguration (noch offen)

| Bereich | Was tun |
|---|---|
| **NFC** | App ID `swiss.atoll.card` → Capabilities → **NFC Tag Reading** anhaken. Entitlement-File `AtollCard.entitlements` ist bereits konfiguriert. |
| **Push Notifications** | App ID → **Push Notifications** anhaken. APNs-Auth-Key in Supabase Edge Function hinterlegen (für Lead-Push). |
| **Wallet Pass Type ID** | Certificates → Pass Type IDs → `pass.swiss.atoll.card.persona` registrieren. `.p12` Cert + WWDR.pem auf Atoll-OS-Server hochladen. Endpoint `/api/wallet/pass` bauen. |
| **URL Schemes** | `atollcard://` ist in `Info.plist` registriert. In Supabase Auth → Redirect URLs `atollcard://auth/callback` hinzufügen. |

Bis das Wallet-Cert da ist, zeigt der "Wallet"-Button einen Hinweis-Dialog statt eines Passes.

## Annahmen, die ich getroffen habe

1. **iOS 26 (nicht iOS 17+ wie im Brief).** Grund: dann kann AtollCard die geteilten Packages `AtollCore` + `AtollDesign` aus dem Monorepo nutzen, die auf iOS 26 / Swift 6 / Liquid Glass laufen. Eine separate iOS-17-Codebase mit duplizierten Models, Auth und Brand-Tokens wäre teurer als der Reichweiten-Gewinn — wir sind im selben Ökosystem wie AtollCal. Rückgängig zu machen indem die beiden Package-Targets auf iOS 17 zurückgenommen werden und die `@Observable`-Stores notfalls auf `@Published` wechseln.
2. **Projekt-Ort `apps/atollcard-native/`** (statt `~/Projects/AtollCard/`) — konsistent mit `atollcal-native` im selben Dispo-Monorepo.
3. **XcodeGen statt manuell gepflegtes `.xcodeproj`** — derselbe Workflow wie AtollCal. Das `.xcodeproj` ist ein Build-Artefakt, nicht im Repo eingecheckt.
4. **Schema embedded `dive_profile` als jsonb in `cards`** statt separater Tabelle — bricht relationale Reinheit, spart aber einen Join und passt zur "ein Karten-State pro Persona"-Realität. Easy zu migrieren, wenn nötig.
5. **Mock-Daten by default** (`Config.useMockData = true`). Du siehst die App sofort populated; das Umstellen ist ein Boolean-Flip.
6. **Default-Persona Dominik mit 3 Karten** im Mock — wer einsteigt, soll das Mockup wiedererkennen.
7. **Wallet-Pass-Signing serverseitig** — der Brief schlägt `PassKit` vor, aber Pass-Cert auf dem Client wäre ein Leak. Stattdessen Edge-Function-Stub auf Atoll OS web (siehe TODO oben).
8. **Lead-Capture ist Web** — die App **empfängt** Leads, **rendert** sie nicht öffentlich. Die Public-Card-Page lebt in `apps/web` (Atoll OS) — passt zum Brief.
9. **Keine ImpressKit, kein Notetaker, kein Team** — wie im Brief explizit ausgegrenzt.
10. **Konversation auf Deutsch**, Localization-Bundle nur `de` (Brief sagt "keine Localization").

## Public Card-Page (Atoll-OS-Web)

Die Seite die der QR-Scanner trifft lebt in `apps/web/src/screens/PublicCardScreen.tsx`. Route: `/c/<slug>`. Kein Login.

**Setup:**
1. Migration `0098_atollcard_public_access.sql` anwenden (Public-Read-RLS).
2. Web-Dev-Server starten: `cd apps/web && npm run dev`
3. Im Browser `http://localhost:5173/c/dominik-cd` öffnen.
4. Sollte deine PADI-CD-Karte zeigen. Scan-Counter in der iOS-App steigt um 1.
5. Lead-Form ausfüllen → submit → Lead erscheint in der iOS-App Inbox.

**Production:** vercel.json im Web-App-Verzeichnis ist schon konfiguriert. Mit `vercel --prod` deployen, dann läuft `https://atoll-os.com/c/<slug>` automatisch.

## Phase 6 — Echtes APNs-Push (wenn du jederzeit Pings willst, auch bei geschlossener App)

Lokale Notifications (Phase 5) feuern nur wenn die App im RAM ist (foreground + kurz background). Für echte Pushes bei komplett geschlossener App brauchst du APNs.

### 6.1 APNs Auth Key generieren

1. https://developer.apple.com/account → **Certificates, Identifiers & Profiles** → **Keys** (links) → **+**
2. Name: `AtollCard APNs Key`
3. Service: **Apple Push Notifications service (APNs)** ankreuzen → Continue → Register
4. **Download** klicken → das `.p8`-File herunterladen. **Speicher es sicher — Apple lässt dich es nur einmal herunterladen.**
5. Notiere die **Key ID** (10-stellig, steht oben auf der Detail-Seite) und deine **Team ID** (`XK8V89P2QV`, oben rechts neben deinem Namen)

### 6.2 Auth Key in Supabase hinterlegen

```bash
cd ~/Desktop/Developer/Dispo
supabase secrets set \
  APNS_KEY_ID=ABCD123456 \
  APNS_TEAM_ID=XK8V89P2QV \
  APNS_BUNDLE_ID=swiss.atoll.card \
  APNS_AUTH_KEY_BASE64=$(base64 -i ~/Downloads/AuthKey_ABCD123456.p8)
```

### 6.3 Edge Function deployen

```bash
cd ~/Desktop/Developer/Dispo
supabase functions deploy atollcard-lead-push --no-verify-jwt
```

### 6.4 pg_net Extension aktivieren

Supabase Dashboard → Database → Extensions → `pg_net` → Enable

### 6.5 Trigger-Migration anwenden

```bash
# Erst die GUCs setzen (Dashboard → Database → Settings → Custom Settings):
#   app.edge_function_base_url = https://<projectref>.supabase.co/functions/v1
#   app.edge_function_anon_key = <dein anon key>
# Dann:
supabase db push
```

(Migration `0100_atollcard_lead_push_trigger.sql`.)

### 6.6 Test

In iOS-App einloggen → Erlaubnis erteilen → `device_tokens`-Tabelle im Supabase Dashboard checken (1 Row sollte erscheinen). Dann Web-Form ausfüllen → Push erscheint im iPhone-Lockscreen.

**Wichtig:** Push-Notifications funktionieren **nicht im iOS-Simulator** (Apple-Limitation) — du brauchst ein echtes iPhone fürs End-to-End-Test.

## Was *nicht* drin ist (Roadmap)

| Feature | Status | Wann |
|---|---|---|
| Echtes Supabase-Backend | Stub-Repositories werfen `notImplemented` | sobald Schema steht |
| Lock Screen / Home Screen Widget | – | Phase 2 |
| Apple Watch Companion | bewusst ausgegrenzt | – |
| iPad-spezifische UI | bewusst ausgegrenzt | – |
| Push-Notifications (APNs-Hook) | UI-Hooks sind da, AuthKey fehlt | sobald APNs konfiguriert |
| Echtes Wallet-Pass-Signing | Service-Klasse fertig, Server-Endpoint fehlt | sobald Pass Type ID Cert |
| Card-Editor (neue Persona anlegen) | nicht implementiert (FAB "+" cycle-routed) | Phase 2 |
| Offline-Queue für Mutationen | SwiftData-Cache noch nicht eingebaut | Phase 2 |
| Universal Links statt nur Custom-URL-Scheme | nur Custom Scheme | Phase 2 |
| Localization (EN/FR) | nur DE | später |

## Datei-Inventar

```
apps/atollcard-native/
├── project.yml                  XcodeGen-Definition
├── README.md                    diese Datei
├── CHANGELOG.md                 Architektur-Entscheide
├── AtollCard/
│   ├── AtollCardApp.swift       @main, Stores aufgesetzt, Deep-Link-Routing
│   ├── Config.swift             Supabase-URL, useMockData-Flag
│   ├── Info.plist               NFC-Permission, URL-Schemes
│   ├── AtollCard.entitlements   NFC + APNs
│   ├── Assets.xcassets/         AppIcon (Placeholder), AccentColor (brandRed)
│   ├── Models/
│   │   ├── Person.swift         persons-Row-Mirror
│   │   ├── Card.swift           cards-Row + CardTheme + DiveProfile
│   │   ├── Lead.swift           card_leads-Row + LeadStatus
│   │   ├── Scan.swift           card_scans-Row + Source/TappedField enums
│   │   └── NFCTag.swift         nfc_tags-Row
│   ├── Repositories/
│   │   ├── CardRepository.swift     Protocol + Mock + Supabase stub
│   │   ├── LeadRepository.swift     Protocol + Mock + Supabase stub
│   │   ├── AnalyticsRepository.swift Protocol + DateRangeOption + DailyCount
│   │   ├── CardStore.swift          @Observable, refresh/upsert/setDefault
│   │   ├── LeadStore.swift          @Observable, groupedByDay()
│   │   ├── AnalyticsStore.swift     @Observable, range + scope toggles
│   │   └── MockSeed.swift           deterministische Demo-Daten
│   ├── Services/
│   │   ├── QRCodeService.swift      CIQRCodeGenerator + QRCodeView
│   │   ├── NFCWriterService.swift   NFCNDEFReaderSession-Wrapper
│   │   ├── WalletPassService.swift  PKAddPassesViewController-Hook
│   │   └── ShareService.swift       UIActivityViewController-Wrapper
│   ├── Theme/
│   │   └── CardTheme.swift          Pastell-Pills + Persona-Gradienten
│   └── Views/
│       ├── RootView.swift           Auth-Gate + Route-Switch + FAB
│       ├── Cards/
│       │   ├── CardsView.swift              Header + Gallery + Recent Leads
│       │   └── PersonaDetailCard.swift      Detail-Block + Quick Actions
│       ├── Leads/
│       │   ├── LeadsView.swift              Inbox mit Filter-Pills
│       │   └── LeadDetailSheet.swift        Detail + → ABook CTA
│       ├── Analytics/
│       │   └── AnalyticsView.swift          KPIs + Swift Charts
│       ├── Settings/
│       │   └── SettingsView.swift           Account / Default / Push / Theme
│       ├── Share/
│       │   ├── FullscreenQRView.swift       Vollbild-QR mit Brightness-Boost
│       │   └── NFCWriteSheet.swift          NFC-Schreib-Sheet
│       └── Components/
│           ├── BizCardView.swift            Persona-Karte (Mockup-Look)
│           ├── PillView.swift               Pastell-Pill + FlowLayout
│           ├── SectionHeaderRow.swift       AtollCal-Style "HEUTE · …"
│           ├── LeadRowView.swift            Inbox-Row
│           ├── Avatar.swift                 Coloured-Initials-Circle
│           ├── FloatingActionBar.swift      FAB mit Avatar in Mitte
│           ├── HeaderBar.swift              Heute-Pill + Big-Title + Tab-Pills
│           ├── StatTriple.swift             3-Stat-Strip + QuickActionGrid
│           └── ToastCenter.swift            @Observable Toast-Pipeline
└── AtollCardTests/              (leer — Tests folgen)
```

## Wer baut weiter?

Larry orchestriert, dispatched aber Tasks an die richtigen Specialists (siehe `apps/atollcal-native/AGENTS.md`-Pattern). Für AtollCard sind die wahrscheinlichsten Routings:

* **Architekturentscheide** → Plan
* **Neue UI-Komponenten** → Mack (oder ui-ux-pro-max skill)
* **Supabase-Repository ausfüllen** → Penn
* **Server-Endpoints (Wallet, Lead-Push)** → Hexa (web/Edge Function)
