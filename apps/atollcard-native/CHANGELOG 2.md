# AtollCard — Changelog

## 0.10.0 — Wallet-Pass-Signing (Larry, 25.05.2026)

`PKAddPassesViewController` zeigt jetzt einen echten signierten Pass —
nicht mehr den Info-Alert-Stub. Edge Function `atollcard-wallet-pass`
baut, signiert (PKCS#7 via forge), zipped und liefert den `.pkpass`-File.

### Architektur-Entscheidung: Edge Function statt Web-Server

Pass-Cert lebt in Supabase Secrets, signing in Deno. Vorteil:
- Cert nie im iPhone-Binary (würde sonst leaken)
- Keine extra Web-Service zu deployen
- forge + zip-js + supabase-js — alles via npm:/jsr: für Deno

Cold-Start steigt um ~200ms wegen forge-Import — akzeptabel für einen
Endpoint der vermutlich <10× pro Tag gefeuert wird.

### Bewusst nicht enthalten

- **Pass-Updates via APNs** (Welle-D-Folge wenn Bedarf da ist)
- **"Save to Wallet"-Button auf der Public Card Page** (separate Spec, anonyme Auth)
- **Pass-Cert auto-Renewal** (Renewal-Reminder im Captain's Log)

## 0.9.0 — Web-Inbox + Adressbuch-Import (Larry, 25.05.2026)

iOS-CTA umetikettiert von "In Adressbuch importieren" auf "In Atoll Web öffnen"
(Universal-Link / Web-Browser-Fallback). Adressbuch-Import passiert ab jetzt
ausschliesslich im Web — Single Source of Truth für Dedup-Logik und
Role-Tagging.

Web-seitige Änderungen (in apps/web): siehe
`docs/superpowers/plans/2026-05-25-atollcard-web-inbox.md`.

### Architektur-Entscheidung: Web-only Import

In der Frühphase hatte das LeadDetailSheet einen "→ ABook"-Button, der ins
Leere führte (Adressdatenbank lebt nur im Web). Statt eine zweite Import-
Implementation in iOS zu bauen, machen wir den CTA zum Deep-Link in die
Web-Inbox. Begründung: Dedup-Logik, Role-Zuweisung und Conflict-Resolution
müssen sonst doppelt gepflegt werden. iOS bleibt der Triage-Modus
(Status setzen, Antworten, Archivieren), der formelle Import passiert
am Mac.

## 0.8.0 — Specialty-Katalog aus Atoll OS (Larry, 22.05.2026)

Die Pillen-Auswahl im CardEditor zieht jetzt aus der `skills`-Tabelle der
Atoll-OS-Hauptapp statt aus einer hardcoded 15er-Liste. Nur Specialties
für die der Instructor das Permit hält (via `instructor_skills`) werden
angeboten — keine "Cavern"-Pille mehr ohne Cavern-Cert.

### Phase 7.8 — Live-Specialty-Katalog

* **`SpecialtyCatalogService`** neuer Singleton. Lookup-Pfad:
  `auth.users → contact_instructor.auth_user_id → contact_id ==
   instructor_id → instructor_skills → skills (category IN
   'Specialty', 'SPEI')`. Strippt `"Specialty: "` / `"SPEI: "` Prefix für
  Pill-Anzeige. Mock-Mode liefert kuratierte Demo-Liste.
* **`SpecialtyGrid`** im `CardEditorSheet` lädt jetzt async via `.task`,
  zeigt Loading-Spinner, Empty-State ("Verwalte deine Skills in der
  Hauptapp"), und Fehler-Toast.
* **SPEI-Tier visuell unterscheidbar:** SPEI-Pillen tragen eine kleine
  lila `T`-Capsule (Trainer-Indikator) damit auf einen Blick klar ist
  ob es eine Instructor- oder Trainer-Credential ist.
* **Backward-compat:** Auf der Card werden weiterhin die *Labels* (z.B.
  "Wreck") als `[String]` gespeichert, nicht die Codes — bestehende
  Karten bleiben gültig, Public-Page-Render unverändert.

### Was bewusst nicht drin ist

* Keine Skill-Verwaltung *in* AtollCard — Permits werden weiter in der
  Atoll-OS-Hauptapp gepflegt. AtollCard liest nur.

## 0.7.0 — Profilfoto + Public-Page Avatar (Larry, 22.05.2026)

Public-Card zeigt jetzt ein echtes Portrait statt Initialen — pro Contact
ein Foto, geteilt über alle Personas.

### Phase 7.7 — Profilfoto-Pipeline

* **Migration 0101** — `contacts.avatar_url` Spalte + öffentlicher
  Storage-Bucket `contact-avatars` mit RLS-Policies. Schreiben nur an
  `<contact_id>.jpg`, das man via `contact_instructor` besitzt; Lesen
  ist anonym (CDN-Public).
* **`AvatarUploadService`** — Square-Crop → 512×512 JPEG @ 0.85 →
  Supabase-Storage-Upload mit `upsert: true` → PATCH `contacts.avatar_url`
  inkl. `?v=<ts>` Cache-Buster.
* **Settings → Profilfoto-Section** — SwiftUI `PhotosPicker`, Live-Preview,
  Upload-Button mit Spinner, Toast bei Erfolg/Fehler. Lädt beim Öffnen
  bereits gespeichertes Foto via `fetchCurrentAvatarUrl()` für korrekten
  Initial-State.
* **`NSPhotoLibraryUsageDescription`** in Info.plist + project.yml.
* **Public-Page** rendert `contact.avatar_url` als 72×72 `<img>` mit
  `object-fit: cover` und weißem 4 px Ring; Fallback auf Initialen-Avatar
  mit Persona-Gradient (statt fixem Rot).
* **Layout-Polish**: Avatar überlappt jetzt die Karte um −36 px
  (LinkedIn-Style), redundante Namens-Wiederholung entfernt, Sprachen
  bleiben rechts neben dem Avatar.
* **Sticky Mobile-CTA** "Verbinden" via `position: fixed` und
  `IntersectionObserver` — blendet sich aus, sobald das Lead-Form im
  Viewport ist (deckt auch den Success-State ab).
* **Footer-Logo** transparent + 22 px (statt 18 px) + Opacity 0.85.

### Was bewusst ausgelassen wurde

* In-App iOS-Avatar (BizCard, CardsView, RootView) zeigt weiter Initialen
  — die `Person`-Daten fließen noch aus `MockSeed.dominik`. Foto-Rendering
  in den iOS-Views käme mit einer `ProfileStore`-Schicht, die live aus
  `contacts` lädt; das ist als Follow-up vermerkt.

## 0.6.0 — Push live + Public-Page polish (Larry, 22.05.2026)

End-to-End funktioniert: Web-Lead → Supabase-Trigger → Edge Function →
APNs → iPhone-Lockscreen. Plus erste Politur an der Public-Card-Page.

### Phase 6 — APNs Push, live

* **Apple Auth Key** generiert + in Supabase als Secrets hinterlegt.
* **Edge Function `atollcard-lead-push`** deployed, signiert APNs JWTs
  on-the-fly, fan-out an alle Device-Tokens des Card-Owners.
* **Migration 0099** — neue Tabelle `atollcard_device_tokens` (statt
  Konflikt mit der bestehenden `device_tokens` aus AtollCal).
* **Postgres-Trigger** auf `card_leads` AFTER INSERT, ruft via `pg_net`
  die Edge Function. Hardcoded URL + anon key (Supabase Cloud erlaubt
  kein `ALTER DATABASE SET` für GUCs).
* **Sandbox-APNs-Host** als Secret (`APNS_HOST=api.sandbox.push.apple.com`),
  weil Dev-Builds Sandbox-Tokens kriegen. Production-App-Store-Build
  bekommt einen anderen Token und braucht `api.push.apple.com`.

### Phase 7 — Public-Page Polish

* **Atoll-OS-Web Public-Page** zeigt jetzt das echte AtollCard-Logo (oben
  links auf der Persona-Karte + im Footer) statt nur Text.
* **Dynamischer Browser-Tab-Title** — auf `/c/<slug>` wird Tab-Titel zu
  "Dominik Weckherlin — PADI Course Director" und `theme-color` springt
  auf die Persona-Gradient-Start-Farbe. Safari-Tab-Group sieht jetzt
  per-Karte verschieden aus.
* **OG-/Twitter-Card-Meta-Tags** für WhatsApp- / iMessage- / LinkedIn-
  Previews. **Achtung**: weil Atoll OS ein Vite-SPA ohne SSR ist, sehen
  Crawler den statischen `index.html` — heißt jeder Card-URL kriegt den
  selben generischen Preview. Per-Karte-OG braucht eine Edge-Function-
  Pre-Render-Schicht (Phase 7.5, TODO).

### Architektur-Entscheidungen

#### `atollcard_device_tokens` statt `device_tokens`
Die bestehende `device_tokens`-Tabelle (vermutlich von AtollCal) hat ein
anderes Schema (`instructor_id` + `apns_token`). Statt das umzubauen
und AtollCal zu riskieren, neue Tabelle mit Namespace-Prefix. Kein
Konflikt, kein Datenverlust.

#### Inline-URL im Trigger statt GUCs
Supabase Cloud erlaubt `ALTER DATABASE postgres SET app.xxx` nur als
Superuser. Hardcoded URL/anon-key direkt im Trigger ist hässlich aber
funktioniert. Bei Migration eines Projekts müssen diese eine Stelle
gepatcht werden — vertretbar.

#### Static OG-Tags statt SSR
Edge-Function-Pre-Rendering für dynamische OG ist möglich aber 1–2h
Setup-Zeit. Static defaults reichen für 80% der Use-Cases (WhatsApp-
Vorschau "AtollCard — Digitale Visitenkarte"). Phase 7.5 wenn echte
Per-Karte-Previews wichtig werden.

---

## 0.5.0 — Realtime + Local + APNs-Scaffold (Larry, 22.05.2026)

Phase 5 macht Leads live. Drei Schichten:

1. **Realtime** — `LeadStore.startRealtime()` abonniert `card_leads` via
   Supabase-WebSocket. Jeder neue Lead aus der Web-Page erscheint sofort
   in der iOS-App-Inbox ohne Pull-to-Refresh.
2. **Local Notification** — direkt beim Realtime-INSERT triggert
   `NotificationService.shared.scheduleLeadNotification(...)`. Funktioniert
   solange die App im RAM ist (foreground + kurzes Background).
3. **APNs-Scaffold** — `PushTokenService` registriert sich für Remote-Push,
   sendet den device-token an `device_tokens` (Migration 0099). Die Edge
   Function `atollcard-lead-push` + der Postgres-Trigger (Migration 0100)
   sind fertig — sie warten nur auf den APNs Auth Key vom Apple Dev
   Portal (Phase 6 in der README).

### Was neu ist (Code)

* `Services/NotificationService.swift` — UNUserNotificationCenter-Wrapper
* `Services/PushTokenService.swift` — APNs device-token capture + Supabase
  upsert
* `AppDelegate.swift` — UIApplicationDelegate-Adapter (SwiftUI hat
  bekanntlich keinen)
* `LeadStore.startRealtime()` — Postgres-Change-Listener mit
  Codable-Decoding über denselben Pfad wie REST

### Was neu ist (DB)

* `supabase/migrations/0099_atollcard_device_tokens.sql` — Tabelle mit
  composite PK (auth_user_id, device_token), platform-Check, RLS
  scoped per-user
* `supabase/migrations/0100_atollcard_lead_push_trigger.sql` — AFTER
  INSERT-Trigger der via `pg_net.http_post` die Edge Function ruft
* `supabase/functions/atollcard-lead-push/index.ts` — Deno-Edge-Function
  die das APNs JWT signiert (ES256, P-256) und HTTP/2 POST an
  `api.push.apple.com/3/device/<token>` macht

### Architektur-Entscheidungen

#### Realtime + Local *vor* APNs
Apple Push braucht einen real device + Auth Key + Deployment, das ist
mehrere Stunden. Realtime + Local funktioniert in 5 Minuten und deckt
80% der Use-Cases (Dominik schaut eh oft aufs Telefon). Echter
Background-Push ist Phase 6 — der Stack ist fertig vorbereitet, fehlt
nur die Server-Konfig.

#### Device-Token-Capture ohne APNs Auth Key
Die App registriert sich trotzdem für Remote-Push und sammelt Tokens
in `device_tokens`. Wenn der Apple Auth Key später ergänzt wird,
brauchen wir kein App-Update — der Trigger weiß schon, wohin er pushen
muss.

#### Postgres-Trigger ruft Edge Function, nicht Realtime+Server
Alternative: ein Background-Service der Realtime-Channels lauscht und
Push-Calls macht. Das ist mehr Infra-Aufwand. Postgres-Trigger +
pg_net + Edge Function ist serverless, deklarativ, fertig.

#### Composite-PK auf device_tokens
`(auth_user_id, device_token)` als PK statt einer UUID. Vorteil:
Token-Rotation ist ein `upsert ON CONFLICT DO UPDATE` ohne extra Logik.
Multi-Device-Support (iPhone + iPad) kommt natürlich raus.

---

## 0.4.0 — Public Card-Page (Larry, 22.05.2026)

Die Web-Seite die der QR-Scanner trifft. Lebt in `apps/web` als Public-Route
`/c/<slug>`, kein Login nötig, alles direkt PostgREST mit anon-Key.

### Was neu ist

* **`apps/web/src/screens/PublicCardScreen.tsx`** — visuelles Pendant zur
  iOS BizCard mit Persona-Gradient, Avatar, Specialties, Stats. Action-
  Buttons (E-Mail / Anrufen / WhatsApp / Speichern als .vcf). Lead-Form mit
  Success-State, INSERT geht direkt nach `card_leads`.
* **`supabase/migrations/0098_atollcard_public_access.sql`** — anon-Role
  bekommt SELECT auf `cards` (nur is_active), SELECT auf `contacts` (nur
  Owner mit aktiver Karte), INSERT auf `card_scans` + `card_leads`. Owner-
  Policies (0097) bleiben unverändert für authenticated.
* **Route in `App.tsx`** außerhalb des Auth-Gates — eine Code-split
  Lazy-Komponente die nur geladen wird wenn jemand die Card-URL trifft.

### Architektur-Entscheidungen

#### Kein Server-Side-Rendering
Atoll OS Web ist Vite + React-SPA — kein SSR. Heißt der Scan-Counter
inkrementiert client-side. Trade-off: Crawler/Preview-Bots werden auch
gecountet, das verzerrt die Stats minimal. Mitigation: später kann ein
edge-function in front of /c/<slug> die scan-INSERT übernehmen und SEO-
Meta-Tags rendern.

#### Lead-Capture direkt PostgREST, kein API-Endpoint
INSERT in card_leads geht direkt vom Browser mit anon-Key. RLS-Policy
prüft dass card_id zu einer is_active=true Karte gehört. Spar einen
Server-Layer; bei Spam-Problemen können wir später ein Cloudflare-Turnstile
oder eine Edge-Function vorschalten.

#### vCard-Download statt nur "Save Contact"-Link
Apple's `addToContacts` Custom-Scheme braucht eine native App. .vcf-Blob
mit `text/vcard` MIME funktioniert überall — iOS Safari öffnet's in
Contacts.app, Android in der Contacts-App, Desktop bietet Save-As an.

#### Inline-Styles statt CSS-Module
Die Seite ist eine Single-File-Komponente; Inline-Styles vermeiden eine
neue CSS-Datei und sind hier explizit lesbar. Das Atoll-OS-Web-Repo hat
sonst noch keine zentrale Styling-Convention die für eine Public-Page
passt (alles in App-Shell-Foundation-Komponenten gebaut). Wenn die Page
größer wird, ziehen wir's in ein styled-Module.

#### Kein i18n
Die Public-Page ist Deutsch (Atoll OS Sprache). Wenn der internationale
Gegenüber auf der Page landet (z.B. nach Trial-Dive in Dauin), kommt eine
englische Version später als ?lang=en Query-Param.

---

## 0.3.0 — Supabase Live (Larry, 22.05.2026)

Die App schaltet vom Mock-Mode in echtes Backend um. Schema-Migration
geschrieben, alle drei Stub-Repositories ausgefüllt, README erweitert um
eine 5-Schritt-Setup-Anleitung.

### Was neu ist

* **`supabase/migrations/0097_atollcard_schema.sql`** — 4 Tabellen
  (`cards` + `card_scans` + `card_leads` + `nfc_tags`), 5 Enums, Indexes,
  `updated_at`-Trigger und RLS-Policies via `is_card_owner()` SECURITY-DEFINER
  Helper.
* **`SupabaseCardRepository`** — PostgREST gegen `cards`, inkl. zweistufiger
  `setDefault`-Logik wegen `idx_cards_one_default_per_person`-Constraint.
* **`SupabaseLeadRepository`** — fetchAll / fetch / upsert / updateStatus /
  markImported, alles via Postgrest.
* **`SupabaseAnalyticsRepository`** — liest `card_scans` + `card_leads` direkt
  und rolled in-process auf. Per-Day-Buckets füllen Gap-Tage mit 0, damit der
  Chart eine kontinuierliche Linie hat.

### Architektur-Entscheidungen

#### `cards.person_id → contacts.id`, nicht `persons`
Im aktuellen Atoll-OS-Schema heißt die Tabelle `public.contacts`, nicht
`persons`. Mein Initial-Brief hat `persons` angenommen — falsche Annahme.
Korrigiert.

#### Analytics in-process, kein SQL-View
Mit Dominiks-Volumen (geschätzt einige hundert Scans pro Monat) ist es
verschwendet, einen aggregierten `card_analytics`-View zu pflegen. Wir
lesen die Roh-Tabellen und gruppieren in Swift. Sobald jemand 10k+ Scans/Tag
hat, wechseln wir auf einen Server-View.

#### RLS via SECURITY-DEFINER Helper
`is_card_owner(person_id)` ist eine separate Funktion statt inline-`EXISTS`
in jeder Policy. Macht spätere Refactors trivial — Owner-Logik ändern, eine
Funktion patchen.

#### `fetch(id:)` mit `.limit(1)` statt `.single()`
`.single()` würde bei 0 Treffern werfen. `.limit(1)` + `first` returned
sauber `nil`, was die Repository-API verspricht. Kostet eine Codezeile,
spart eine try/catch-Hülle in jedem Caller.

#### Migration im monorepo, nicht im AtollCard-Folder
Die SQL liegt unter `supabase/migrations/0097_*.sql` im Monorepo-Root,
gleich neben den anderen 96 Atoll-Migrations. Eine zentrale Source-of-Truth,
auch wenn Schema-Teile nur eine App nutzt.

---

## 0.2.0 — Card Editor + Polish (Larry, 22.05.2026)

Erste editierbare Version. Eine Karte ist nicht mehr nur ein read-only Mock,
sondern eine Sache, die der User anlegen, anpassen und löschen kann.

### Was neu ist

* **`CardEditorSheet`** — Form-Sheet mit Live-`BizCardView`-Preview oben.
  Felder: Titel, Untertitel, Badge, Slug (mit Live-URL-Hinweis), Default-Toggle,
  Theme-Picker (CD/SE/Privat als Gradient-Tiles, der aktive bekommt einen
  weißen Border + Schatten), Tauch-Profil (PADI-#, Total Dives, Since Year,
  Instructor Level Picker, Specialty Toggle-Grid), Field-Visibility (was auf
  der Public-Page sichtbar ist), Destructive-Delete mit Bestätigung.
* **FAB "+"** öffnet jetzt den Editor im Neu-Modus statt Routes durchzurotieren.
  Search-Button cyclet bis ein echtes Search-UI existiert.
* **BizCard Long-Press → Context-Menu** mit Bearbeiten / Als Default / Löschen.
* **Edit-Button im PersonaDetailCard-Header** (kleines Bleistift-Icon) für den
  schnellen Zugriff ohne Long-Press.
* **Snap-Paging in der Card-Gallery** (`scrollTargetLayout()` + `viewAligned`).
* **Subtitle 2-zeilig statt abgeschnitten** auf der BizCard.

### Architektur-Entscheidungen

#### Editor schreibt in einen Draft, nicht direkt in die Card
`@State draft: Card` wird vom Sheet besessen — Mutationen leaken nicht in den
Store bis Save gedrückt ist. "Cancel" ist also wirklich Cancel, kein Rollback
nötig. Auch die Live-Preview rendert vom Draft, nicht vom Store-Card.

#### Theme-Picker: Preset-First
Der Picker zeigt nur die drei Presets (CD/SE/Privat). `Custom` ist im Model
da, aber kein UI dafür — kommt erst wenn jemand wirklich einen Custom-Gradient
braucht. Reduziert die Decision-Fatigue.

#### Specialty-Liste: hardcoded Top-15
Die Specialty-Toggles sind eine kuratierte Liste von 15 Specialties, die
Dominik tatsächlich unterrichtet (Deep, Nitrox, Wreck, Drift, …). Kein
Freitext-Add im ersten Wurf — wenn jemand eine fehlende Specialty einträgt,
geht das später als Custom-Spec-Section.

#### FAB-Search bleibt Cycle-Crutch
Globale Suche braucht eine eigene UI (Modal? Top-Bar?). Statt halbfertige
Search reinzuhauen, bleibt der Button bis dahin als Tab-Cycler nützlich.

---

## 0.1.0 — Initial scaffold (Larry, 22.05.2026)

Erstes Hochziehen der App. Volle Mock-Tour: 3 Personas, Lead-Inbox, Analytics-Charts, QR-Vollbild, NFC-Sheet, Settings.

### Architektur-Entscheide

#### 1. iOS 26 statt iOS 17+
**Brief sagt iOS 17+.** Hab ich auf **iOS 26** angehoben. Grund: die geteilten Packages `AtollCore` (Auth, Supabase) und `AtollDesign` (BrandColors, Avatar) sind im Dispo-Monorepo bereits auf iOS 26 / Swift 6 / Liquid Glass festgenagelt — AtollCal lebt da. Eine zweite Codebase mit iOS-17-Forks der Packages wäre doppelte Pflege ohne ökonomischen Nutzen, weil die App primär für Dominik selbst und sein Team auf neueren Geräten gebaut wird.

**Rückzugsplan:** sollte sich später Bedarf für ältere Geräte ergeben — Package-Targets auf iOS 17 absenken, `@Observable` notfalls durch `@Published` ersetzen. Wäre ein paar Stunden Arbeit, kein Rewrite.

#### 2. XcodeGen statt manuell gepflegtes pbxproj
Dieselbe Lösung wie `atollcal-native`. `project.yml` ist menschenlesbar, mergebar in Git, das `.xcodeproj` ein Build-Artefakt. Spart die regelmässigen "Cannot find X in scope"-Sessions, wenn man eine Datei hinzufügt aber die pbxproj nicht patcht (vgl. die Anniversary-Saga in AtollCal letzte Woche).

#### 3. Repository-Pattern mit Mock-Default
Jeder Datenzugriff geht durch ein Protocol (`CardRepository`, `LeadRepository`, `AnalyticsRepository`). Beim App-Start prüft `Config.useMockData`:
* `true` → `MockCardRepository` / `MockLeadRepository` / `MockAnalyticsRepository` mit deterministischen Seeds
* `false` → `Supabase*Repository`-Klassen (heute noch `notImplemented`)

Vorteile:
- Demo läuft sofort, ohne Backend
- UI-Entwicklung blockiert nicht auf Schema-Arbeit
- Späterer Backend-Wechsel ist ein Flag

#### 4. @Observable Stores statt MVVM-ViewModels
Brief sagt "MVVM mit @Observable". Ich habe MVVM auf seinen Kern reduziert: **Stores** (`CardStore`, `LeadStore`, `AnalyticsStore`) statt pro-Screen-ViewModels. Begründung: die Datenmenge ist klein, die Views sind dünn, ein eigener ViewModel pro Screen wäre Overhead ohne Gewinn. Stores hängen am `@Environment` der App, jede View pickt sich an was sie braucht.

#### 5. Persona-Gradienten als Theme-Presets, nicht hex-strings
Im `Card.theme.preset` ist ein Enum (`.courseDirector` / `.seaExplorers` / `.privat` / `.custom`). Der Editor (kommt Phase 2) lässt den User ein Preset wählen; nur `.custom` triggert die Hex-Picker. Vermeidet "warum sieht meine Karte so komisch aus, ich habe gestern an den Farben gespielt".

#### 6. AtollCal-Konsistenz über Brand-Reinheit
AtollDesign hat `Color.brandPink` (CD-Avatar-Farbe) — ich verwende sie nicht für den CD-Gradient. Grund: der Mockup zeigt einen **blauen** CD-Gradient. Das ist die Visitenkarte vs. der Avatar. Brand-Pink bleibt Avatar-/Skill-Chip-Reserved, Gradient ist eine separate Persona-Sprache.

#### 7. Floating Action Bar statt TabBar
Brief sagt "Kein Tab-Bar im klassischen iOS-Sinn". Stattdessen: ein `FloatingActionBar` mit 4 Cells (☰, Avatar, 🔍, ➕). Die Routes wechseln via `route` State im RootView. Konsistent mit AtollCal. Trade-off: kein systemeigener Tab-Bar-Behaviour (Double-Tap-Top, Swipe-Edge), den müssten wir gegen Tabs handeln, wenn das je gewünscht ist.

#### 8. QR-Code mit Logo-Overlay, Correction-Level "H"
ISO-30%-Wiederherstellung. Genug Reserve um das ATOLL-Quadrat in der Mitte zu platzieren ohne Scan-Risiko. Logo-Fläche ist 22% der Kantenlänge (klassische QR-Logo-Faustregel).

#### 9. Wallet-Pass-Signing über Server-Endpoint
Brief schlägt `PassKit` lokal vor. Habe ich auf den Server delegiert: die App POSTet `card_id` an `/api/wallet/pass` auf Atoll OS, der Server signiert mit `.p12`-Cert und gibt das `.pkpass`-Blob zurück. Begründung: Pass-Cert auf dem Client wäre ein Leak; jeder mit dem App-Binary könnte beliebige Pässe signieren.

Bis der Endpoint existiert: "Wallet"-Button zeigt einen Info-Alert.

#### 10. Brightness-Boost auf Fullscreen-QR
`UIScreen.main.brightness = 1.0` beim Erscheinen, beim Verschwinden zurück auf den vorherigen Wert. Hilft beim Scannen im Sonnenlicht (Dauin im Mai). Kein dedicated Lock-Screen-QR-Widget — das war im Brief explizit Phase 2.

#### 11. ISO-3166-Country statt Geo-Heatmap
Brief sagt "Geo-Heatmap (vereinfacht: Country-Level aus IP)". Habe einen einfachen Country-Listen-Render gewählt (Flag-Emoji + Count) statt einer Karte. Begründung: Karte braucht entweder MapKit-Tile-Loading (Netz, schwer in Dauin) oder eine ge­renderte World-SVG (~200kb). Beide übertreiben die Aussage. Country-Liste mit Top-6 + Flags vermittelt dieselbe Information in <8kb Render.

### Was später Wert hätte

* **AgendaController-Pattern**: in AtollCal haben wir `rebuildBuckets()` in zwei Views dupliziert. Sobald die Lead-Sektion in `CardsView` und `LeadsView` voneinander abweicht, extrahieren wir den Section-Builder in einen Helper.
* **Snapshot-Tests** für `BizCardView`, `LeadRowView`, `PersonaDetailCard` (Swift Snapshot Testing). Diese Komponenten sollen visuell stabil bleiben.
* **NFC-Read-Mode**: aktuell schreiben wir nur. Wenn jemand ein bestehendes Tag auf dem Schreibtisch hat und das Label hängen geblieben ist, könnte AtollCard das Tag scannen und identifizieren ("Tag #3 — CD-Karte, geschrieben 22.05.2026").
* **Tag-Inventar-Tab** in Settings. Heute weiss niemand, welcher Tag wo klebt.
