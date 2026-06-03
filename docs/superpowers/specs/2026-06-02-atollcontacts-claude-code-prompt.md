# Claude-Code-Handoff-Prompt — AtollContacts (ComHub Kontakt-Pillar)

> Im Dispo-Repo in Claude Code einfügen. Der Block unten ist der eigentliche Prompt.

---

Du arbeitest im Monorepo `Dispo` (ATOLL / Atoll-OS). Lies zuerst `AGENTS.md` (du wirst Larry), dann die verbindliche Design-Spec:

`docs/superpowers/specs/2026-06-02-atollcontacts-comhub-pillar-design.md`

**Ziel:** den Kontakt-Pillar im ComHub umsetzen — das Apple-Adressbuch als Basis, angereichert mit dem Atoll-Tauchprofil. Standardfelder sind im Pillar editierbar und werden nach Apple zurückgeschrieben; Tauchdaten leben in Supabase (SSOT) und werden zusätzlich als markierter Block in die Apple-Notiz gespiegelt. Bei Konflikt zwischen diesem Prompt und der Spec gewinnt die Spec.

**Vorgehen (superpowers):**
1. Branch `comhub-contacts` von `comhub-phase0` anlegen. Ist die Spec noch nicht committet, zuerst committen.
2. Mit dem `writing-plans`-Skill einen Implementierungsplan unter `docs/superpowers/plans/` schreiben, zerlegt nach Phase 0 + 1 der Spec (Schema + Lese-Pfad). Plan kurz zur Review vorlegen, bevor Code entsteht.
3. Umsetzung test-driven (`test-driven-development`), `verification-before-completion` vor jeder Fertig-Meldung.

**Arbeitsteilung (Subagenten):**
- Hexa (Supabase): Migrationen `contact_dive_profile` + `contact_apple_link` + RLS (an die bestehende `contacts`-Policy gekoppelt); `padi_level` → agentur-neutrales `level` als nicht-blockierende Backfill-Folge-Migration.
- Sierra (iOS/macOS): `Contacts.framework`-Adapter, der `ContactsProvider` aus `AtollHub` implementiert; Kontaktliste + verschmolzene Detailkarte; Entitlement `com.apple.security.personal-information.addressbook` + `NSContactsUsageDescription` (DE/EN).
- Vex: RLS-/Berechtigungs-Review. Vera: QA der Detailkarte.

**Wiederverwenden, nicht duplizieren:**
- `AtollHub` (vorhanden): `UnifiedContact`, `ContactKey`, `ContactMatcher`, `AppleContactMapper`, `ContactsProvider`. Neu als reine, unit-testbare Typen in `AtollHub`: ein anbieter-neutraler `DiveProfile` und ein Notiz-Block-Renderer (idempotent, ersetzt nur den eigenen Marker-Block).
- `AtollDesign` für die UI (Glass-Theme, BrandColors).
- Supabase-Projekt `axnrilhdokkfujzjifhj`; PostgREST + Realtime + RLS bestehen. Apple bleibt kanonisch für Standardfelder (kein PII-Doppelspeicher in Supabase, nur Match-Key).

**Scope dieses Durchstichs:** Phase 0 (Schema + `DiveProfile`-Typ) und Phase 1 (Lese-Pfad: Contacts-Permission, Apple-Adapter, Liste + verschmolzene Karte read-only). Vor Phase 2 (Standard-Write-back via `CNSaveRequest`) stoppen und zur Freigabe vorlegen.

**Tests müssen grün sein:** `cd swift-packages/AtollHub && swift test` — `ContactMatcher` (Treffer/Confidence), `AppleContactMapper`-Round-trip, Notiz-Block-Renderer idempotent (zweimal schreiben = keine Änderung; Fremdtext in der Notiz bleibt erhalten).

macOS zuerst; iOS fällt aus demselben Target ab.
