# DSG-One-Pager — TSK Dispo

> Diese Notiz fasst zusammen, wie TSK Dispo persönlichen Daten der TL/DM behandelt
> und ob das mit dem Schweizer Datenschutzgesetz (revDSG, ab 1. Sept 2023)
> sowie der DSGVO vereinbar ist.

## TL;DR

- ✅ **Datenhaltung in der EU** (Supabase Frankfurt) — unter rev. DSG zulässig
- ✅ **Minimaldatenprinzip** — wir speichern nur Name, PADI-Nr, Email, Telefon, Saldo
- ✅ **Keine sensiblen Daten** in der App (keine Bankdaten, keine Geburtsdaten, keine SVN, keine Adressen)
- ✅ **Privatsphäre**: Saldo ist instructor-privat (nur eigene Sicht; Dispatcher-only Aggregation)
- ⏳ **AVV** mit Supabase + Resend wird vor Voll-Adoption unterzeichnet (Standard-Templates da)
- ⏳ **Datenschutzerklärung** in der App vor Voll-Adoption

## Was wir speichern

| Datentyp | Sensitivität | Wo gespeichert |
|---|---|---|
| Name, PADI-Nr | niedrig | `instructors` Tabelle |
| Email | niedrig | `instructors.email` (für Login) |
| Telefon | niedrig | `instructors.phone` (optional, für WhatsApp-Direkt) |
| Avatar-Initialen + Farbe | niedrig | `instructors.initials`, `.color` |
| Skill-Zuordnungen | niedrig | `instructor_skills` |
| Verfügbarkeit (Urlaub, Abwesenheit) | mittel | `availability` |
| Saldo + Bewegungen | mittel | `account_movements` (instructor-privat via RLS) |
| Auth-Login-Session | mittel | Supabase `auth.users` |

## Was wir NICHT speichern

- ❌ Geburtsdatum
- ❌ Adresse / Wohnort
- ❌ Bank- oder Kontodaten
- ❌ Sozialversicherungsnummer (AHV)
- ❌ Krankheits-Diagnosen oder medizinische Daten
- ❌ Profilfotos (nur Initialen)

## Wer sieht was?

| Rolle | Zugriff |
|---|---|
| **Dispatcher** | alles (Kurse, alle TL/DM-Profile, alle Saldi, alle Bewegungen) |
| **Instructor (TL/DM)** | alle Kurse + Profile (read-only Public-Felder); **nur eigener Saldo + eigene Bewegungen** |
| **Anonyme** | nichts (Auth-Wall) |

Durchgesetzt durch **Postgres Row-Level-Security**, also auf Datenbank-Ebene — nicht nur in der UI. Selbst wenn jemand die API direkt anspricht, sieht er nichts, was er nicht sehen darf.

## Datentransfer

- **EU → Schweiz**: TL/DM in der Schweiz greifen via HTTPS auf Daten in Frankfurt zu. Unter rev. DSG keine kritische Übermittlung (EU = "angemessenes Schutzniveau").
- **Email-Versand**: Login-Magic-Links und Notifications gehen via Resend (EU-Region). Empfänger ist immer der Inhaber der jeweiligen Email-Adresse — kein Drittversand.
- **Backups**: tägliche Snapshots in Supabase (7 Tage). Wöchentlicher Excel-Export bleibt im Supabase-Storage (auch EU).

## Auftragsverarbeitungs-Vertrag (AVV)

- **Supabase**: bietet Standard-AVV via [supabase.com/docs/company/dpa](https://supabase.com/docs/company/dpa)
- **Resend**: bietet Standard-AVV via [resend.com/legal/dpa](https://resend.com/legal/dpa)
- **Vercel** (Frontend-Hosting): bietet Standard-AVV via [vercel.com/legal/dpa](https://vercel.com/legal/dpa)
- **Infomaniak** (Domain + Mail): Schweizer Anbieter, eigener AVV

→ Alle drei werden vor Voll-Adoption durch TSK unterzeichnet. Heute (Pitch-Phase ≤ 5 Tester) noch nicht zwingend notwendig.

## Risiken & Migrationspfade

| Risiko | Mitigation |
|---|---|
| Supabase pleite / Preiserhöhung | Supabase ist Open-Source. Self-Hosting auf Hostinger/Schweizer-Server jederzeit möglich (Docker-Compose). |
| Vercel pleite / Preiserhöhung | Frontend ist statisches Build → kann auf jedem Webhoster (auch Infomaniak) gehostet werden. |
| EU-Datenschutz-Skandal | Migration auf rein Schweizer Hoster (Infomaniak, Hostinger CH) ohne Code-Änderung möglich. |
| TSK-Owner kündigt → wer hat die Daten? | Wöchentlicher Excel-Export im alten Format. Vollexport jederzeit möglich. |

## DSG-Kontaktperson

- **Datenverantwortliche Stelle**: TSK ZRH (Adresse einfügen)
- **Datenbearbeiter**: Dominik Weckherlin (App-Betreiber während Pitch-Phase)
- **Auskunftsrecht / Löschungsrecht**: Anfrage formlos an `dominik@weckherlin.com`
- **Aufsichtsbehörde**: Eidgenössischer Datenschutzbeauftragter (EDÖB)

## Nicht abgedeckt (für volle Compliance vor Roll-out zu klären)

- [ ] Datenschutzerklärung in der App veröffentlichen (Footer-Link)
- [ ] Cookie-Banner — aktuell nutzen wir nur essenziellen Auth-Cookie, kein Banner nötig (gemäss revDSG-Auslegung)
- [ ] Aufbewahrungsrichtlinie definieren (wie lange werden Daten ehemaliger TL/DM behalten?)
- [ ] Audit-Log für Datenzugriff (kommt mit pgAudit, falls TSK das fordert)
- [ ] Schriftliche Vereinbarung zwischen TSK und allen TL/DM-Loginern, dass ihre Daten in der App stehen
