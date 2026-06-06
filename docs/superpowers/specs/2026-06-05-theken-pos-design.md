# Theken-POS (Phase 1) — Design-Spec

**Datum:** 2026-06-05
**Status:** Freigegeben (Brainstorming), bereit für Implementierungsplan
**Scope:** Phase 1 — Kern-Kasse. TL/DM-Rabatte & Konto-Buchung sind Phase 2 (eigener Spec).

## 1. Ziel

Eine eigenständige Theken-Kasse, an der Front-Desk-Personal (Dispatcher/Owner/CD) Waren direkt verkauft — ohne vorher einen Kundendatensatz öffnen zu müssen. Heute läuft ein Verkauf nur über Kontakt → Finanz-Tab → Checkout; `/shop` ist reine Katalog-/Lagerverwaltung. Diese Spec ergänzt eine dedizierte Kasse, die auf dem bestehenden, getesteten `pos_checkout`-RPC aufsetzt.

## 2. Entscheidungen (aus dem Brainstorming)

- **Oberfläche:** dedizierte Theken-Kasse mit Produkt-Grid + Tap-to-Cart (nicht das bestehende CheckoutSheet wiederverwenden).
- **Laufkundschaft:** Kundenauswahl mit „Laufkundschaft" als Default. Kunde suchbar, sonst Sammelkontakt.
- **Barcode:** Scan-Eingabe (USB-Scanner = Tastatur + Enter) → Artikel in den Warenkorb.
- **Rabatte:** in der DB festgehalten (`order_lines.discount_*`), nicht nur als effektiver Preis — Grundlage der späteren TL/DM-Abrechnung.
- **Beleg:** druckbarer Beleg über Browser-Druck (Print-to-PDF), kein Server-PDF.
- **Einstieg:** prominente Kachel auf „Heute" (`TodayScreen`, `/heute`) + Sidebar-Eintrag.
- **Rollen:** nur Dispatcher/Owner/CD (entspricht dem `is_dispatcher()/is_owner()`-Guard von `pos_checkout`; Instruktoren können keinen Verkauf abschließen).

## 3. Architektur-Überblick

- Neue Route `/kasse` → `PosScreen` (lazy in `App.tsx`), rollen-gegated.
- Sidebar `ITEMS`: `{ to:'/kasse', icon:'wallet', i18nKey:'pos', roles:['dispatcher','owner','cd'] }`.
- `TodayScreen`: prominente „Kasse öffnen"-Kachel (rollen-gegated) → navigiert nach `/kasse`.
- Verkauf läuft unverändert über `pos_checkout(contact_id, lines, method, pay)` → Order → Rechnung → Zahlung → Lagerabgang. Erweiterung nur um Rabatt (siehe §5).

## 4. Datenmodell-Änderungen

**Migration A — Rabatt auf Positionen.** Additive Spalten auf `order_lines`:
- `discount_pct NUMERIC(5,2) NOT NULL DEFAULT 0` (0–100)
- `discount_chf NUMERIC(10,2) NOT NULL DEFAULT 0` (≥ 0)
Netto je Position = `round((quantity * unit_price - discount_chf) * (1 - discount_pct/100), 2)`, geklemmt auf ≥ 0. Beide Felder erlauben %- oder CHF-Nachlass; UI nutzt eines pro Position.

**Migration B — Laufkundschaft-Sammelkontakt.** Idempotenter Seed eines `contacts`-Eintrags (kind `person`, `first_name='Laufkundschaft'`, `last_name='(Theke)'`, Tag `walk_in`). Da `contacts` aktuell effektiv single-tenant (TSK) ist, genügt ein Eintrag. Frontend löst die ID via `contacts WHERE 'walk_in' = ANY(tags)` auf. (Mehrtenant-fähig in Phase 2, falls `contacts` getenant wird.)

**Barcode-Lookup (kein Schema-Change).** Die Katalog-Query (`retailQueries`/`useCatalog`) wird um `barcode` ergänzt; der Scan matcht in-memory gegen den geladenen Katalog (`product_variants.barcode`, Unique pro `(tenant_id, barcode)`). Kein neues RPC nötig.

## 5. Backend

`pos_checkout` wird erweitert, sodass jede Zeile in `p_lines` optional `discount_pct`/`discount_chf` trägt; das RPC berechnet den Netto-Positionspreis serverseitig (Formel §4), schreibt ihn in die Rechnung und hält den Rabatt auf `order_lines` fest. Guard, Tenant-Logik, Lagerabgang und Journal bleiben unverändert. CREATE OR REPLACE erhält die bestehenden EXECUTE-Grants. pgTAP wird um den Rabatt-Pfad ergänzt.

## 6. Frontend-Komponenten

- `screens/pos/PosScreen.tsx` — Zwei-Spalten-Layout. Links: Suchfeld + Barcode-Feld + Produkt-Grid (Karten: Name, Preis, Bestand; Tap → Warenkorb). Rechts: `CartPanel`.
- `screens/pos/CartPanel.tsx` — Kundenauswahl-Chip (Default Laufkundschaft) + Zeilen (Produkt, Menge ±, Preis, Rabatt %/CHF, Zeilensumme, ×) + Summen (Zwischensumme, Rabatt, Steuer, Total) + Zahlart + „Kassieren".
- `screens/pos/CustomerPicker.tsx` — Kontaktsuche (vorhandenes Muster, vgl. AddRelationshipSheet/Rental-Checkout) mit Reset auf Laufkundschaft.
- `screens/pos/BarcodeInput.tsx` — autofokussiertes Feld; Enter → In-Memory-Lookup → Warenkorb; unbekannt → Inline-Fehler.
- `screens/pos/ReceiptView.tsx` — druckbarer Beleg (Shop-Kopf, Positionen inkl. Rabatt, Steuer, Total, Zahlart, Datum, Rechnungsnr.) + „Drucken" (`window.print()` mit `@media print`-Regeln, die die App-Chrome ausblenden). Rendert aus dem In-Memory-Warenkorb; Rechnungsnummer aus dem `pos_checkout`-Rückgabewert (sonst per `invoice_id` nachgeladen).
- `lib/posQueries.ts` + `hooks/usePos.ts` — Laufkundschaft-Resolver, Barcode-Match, Checkout-Mutation (erweitert um Rabatt).
- `screens/TodayScreen.tsx` — „Kasse öffnen"-Kachel (rollen-gegated).
- `components/Sidebar.tsx`, `App.tsx` — Eintrag + Route. `i18n/locales/de.json`+`en.json` — `pos.*` + `nav.pos`.

## 7. Datenfluss

1. Kasse öffnen (`/kasse`). Kunde = Laufkundschaft (Default) oder gesucht.
2. Artikel zufügen: Tap auf Grid-Karte **oder** Barcode-Scan → Warenkorb-Zeile (Menge erhöht sich bei Wiederholung). Serialisierte Artikel verlangen Seriennummer (vorhandene Logik).
3. Optional Rabatt je Zeile (%/CHF). Summen live.
4. Zahlart wählen, „Kassieren" → `pos_checkout(contactId, lines+discount, method, payNow)`.
5. Erfolg → `ReceiptView` (Druck/PDF) + Warenkorb-Reset.

## 8. Fehlerbehandlung / Edge Cases

- Leerer Warenkorb → „Kassieren" deaktiviert.
- Unbekannter Barcode → Inline-Fehler, kein Zufügen.
- Serialisierter Artikel ohne gewählte Seriennummer → Checkout blockiert.
- Lager nicht ausreichend → Fehler aus `pos_checkout`/Inventar wird angezeigt.
- Rabatt < 0 oder > 100 % bzw. Netto < 0 → Validierung im UI + Klemmung serverseitig.
- Laufkundschaft-Seed fehlt → klare Fehlermeldung mit Hinweis auf Migration.

## 9. Rollen & Sicherheit

Route, Sidebar-Eintrag und Today-Kachel rollen-gegated auf Dispatcher/Owner/CD via `useCurrentUser`/`canEditOps`. Defense-in-depth: der `pos_checkout`-Guard (`is_dispatcher() OR is_owner()`) bleibt die harte Grenze.

## 10. Tests

- pgTAP: Rabatt-Pfad — `pos_checkout` mit `discount_pct`/`discount_chf` → Rechnungs-Netto korrekt, Rabatt auf `order_lines` festgehalten, Lagerabgang unverändert.
- Bestehende pos_checkout-/Inventar-Tests bleiben grün.
- Frontend: `npm -w @tsk/web run typecheck`; manueller Klicktest gegen lokale Supabase.

## 11. Nicht in Phase 1 (→ Phase 2, eigener Spec)

- TL/DM-Rabatt aus **Kategorie × Rolle**-Matrix (DM/TL/Partner), gemappt auf `product_categories` (siehe Memory `tsk-tldm-einkaufskonditionen`).
- „Auf TL/DM-Konto buchen" = Belastungs-`account_movement` auf das **Saldo** (nicht store_credit).
- Sonderfälle: Gratis-Luft (nicht übertragbar), PADI-Memberpreise, Miete auf Anfrage, Kombi-Verbot mit Aktionen.

## 12. Hinweise zur Umsetzung

- CHF-Rabatt vs. %-Rabatt pro Zeile: Schema unterstützt beide; UI startet mit einem `%`/`CHF`-Umschalter pro Position. Falls nur % gewünscht, kann `discount_chf` ungenutzt bleiben.
