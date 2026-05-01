# Pitch-Demo-Skript — TSK Dispo

**Zielpublikum**: TSK ZRH Inhaber + ggf. 1–2 Mit-Entscheider
**Setting**: Mac/iPad, Live-Domain `https://dispo.course-director.ch`
**Dauer**: 12–15 min Demo + 10 min Q&A
**Ziel**: Inhaber sagt "Ja, das ersetzt unsere Excel-Datei"

---

## Vor dem Termin (1× einrichten)

- [ ] Browser-Tabs vorbereiten:
  1. `https://dispo.course-director.ch/heute` (eingeloggt als Dispatcher)
  2. Die Excel-Datei `2026 TL_DM Abrechnung TSK ZRH 2026.xlsx` (zum Vergleich)
  3. Eine WhatsApp-Test-Gruppe mit Dir + 1 Test-User
- [ ] iPad bereithalten als zweites Gerät (für Instructor-View)
- [ ] In TweakPanel: Akzent auf TSK-Blau (`#0A84FF`), Sidebar-Layout
- [ ] Test-Login als Lukas Bader oder Annick auf iPad bereit

## 1 · Einstieg (90 Sek)

> "Ich zeige euch, was ich in den letzten Wochen gebaut habe — eine App, die unsere Excel-Datei für die TL/DM-Dispo ersetzt. Sie läuft auf einem eigenen Server, ist live, und ich nutze sie schon selbst seit X Wochen produktiv."

**Zeigen**: Heute-Dashboard
- Hero-Tile mit Datum + Anzahl heutiger Kurse
- KPI-Cards: 110+ Kurse 2026, 71 aktive TL/DM, 39 zukünftige Einsätze
- Sessions-Timeline heute, Wochenausblick rechts

**Wirkung**: "Die App kennt unsere Realität — sie ist nicht aus der Theorie."

## 2 · Excel-Realität → App-Realität (2 Min)

> "Hier ist genau dieselbe Information, die heute in unserer Excel steht — aber abfragbar, filterbar, durchsuchbar."

**Zeigen**:
- Klick **Kurse** → 110 Kurse 2026 in der Master-Liste
- Filter: Alle / Sicher / Evtl. → zeigt sofort die jeweilige Teilmenge
- Suche "OWD" → alle 14 OWD-Kurse erscheinen
- Klick einen konkreten Kurs → Detail-Panel mit Tabs
- Tab **Zuweisungen** → Avatare aller TL/DM mit Rolle + Bestätigungsstatus

**Vergleich**: nebenher Excel-Tab öffnen, gleiche Zeile zeigen → "diesselbe Info, aber 100× schneller findbar."

## 3 · Konflikt-Erkennung — der "Aha"-Moment (2 Min)

> "Schaut, was passiert wenn ich einen Kurs anlege und versehentlich eine Doppelbelegung produziere."

**Live-Demo**:
- Klick **+ Neuer Kurs**
- Kurstyp **OWD**, Titel **"OWD Demo Test"**, Datum auf einen Tag wo Lukas schon eingeplant ist
- Haupt-Instructor: **Lukas Bader**
- → Sofort orange Banner: ⚠ *"Konflikt: Lukas Bader ist am 12. Januar bereits zugewiesen für 'OWD DRY GK01' als haupt"*
- Speichern bewusst nicht klicken — Sheet schließen

**Wirkung**: "Das passiert in der Excel **nicht** — da merkt man's erst, wenn der Tag da ist und keiner kommt."

## 4 · Skill-Match (1 Min)

> "Und wenn ich den richtigen Instructor suche — nicht irgendeinen, sondern einen, der die nötige Spezialität hat?"

**Zeigen**: Skill-Matrix
- Filter Kategorie "Specialty"
- Klick auf eine Person → man sieht direkt was sie kann
- "Wer kann DRY?" — visuelles Highlight in der Spalte

## 5 · Saldo-Transparenz (3 Min) ← Vertrauensmoment

> "Der Punkt, der die App vom Excel klar abhebt: jeder TL/DM-Saldo ist **vollständig nachvollziehbar**."

**Zeigen**:
- **Saldi**-Liste → 71 Personen mit Live-Saldo, Δ-Spalte
- Klick auf einen mit großem Δ
- Tab **Saldo** in der Detail-Ansicht → Bewegungs-Journal
- Klick auf eine Bewegung → ausklappbar: Berechnungs-Details
  - Kurstyp, Rolle, PADI-Level, Theorie-Stunden, Pool-Stunden, See-Stunden, Stundensatz
- "Wenn Lukas mich fragt 'wieso nur 406 CHF?' — ich klicke einmal, er sieht's."

**Diff-Erklärung**:
- Die rote Δ-Spalte = Differenz zwischen App-Saldo und Excel-Saldo
- Differenz = manuelle Buchungen (Guru-Bezüge, Spesen) die in Excel direkt eingetragen waren
- → Diese werden in v2 angekoppelt; die Comp-Engine selbst rechnet 1:1 wie unsere Excel

## 6 · TL/DM-Sicht (2 Min) ← starkster Moment

> "Und so sieht das Ganze aus, wenn Lukas oder Annick sich einloggt."

**Wechsel auf iPad** (oder zweiten Browser-Tab):
- Login als Test-Instructor (Lukas)
- **Heute** → ihre eigenen heutigen Einsätze (oder "Heute hast du keine Einsätze")
- **Meine Einsätze** → komplette Liste 2026, gefiltert nach kommend/vergangen
- **Mein Saldo** → ihr eigener Saldo, dasselbe Bewegungs-Journal wie der Dispatcher sieht
- **Mein Profil** → Verfügbarkeit eintragen ("Urlaub 15.–22. März")

**Wirkung**:
- Endlich Transparenz für die TL/DM
- Verfügbarkeit kommt zum Dispatcher, nicht per WhatsApp-Chaos

## 7 · WhatsApp-Bridge (1 Min)

> "Das ändert nichts an unserer WhatsApp-Gruppe — wir nutzen sie weiter."

**Zeigen**:
- Wieder als Dispatcher
- Heute → **Tagesdigest** Button → öffnet WhatsApp mit fertigem Emoji-Text
- In Kurs-Detail: **In Gruppe ankündigen** → vorgefüllte Nachricht mit Datum, Instructor, Pool

> "Ich klicke einen Knopf — die Nachricht ist im Stil, den die Gruppe gewohnt ist. Kein Tippen, kein Tippfehler."

## 8 · Datenhoheit & Vertrauen (1 Min)

> "Drei Sachen, die für uns als Tauchschule wichtig sind:"

1. **Schweizer Domain**: `dispo.course-director.ch`, registriert bei Infomaniak (Genf)
2. **EU-Datenhaltung**: alle TSK-Daten liegen in Frankfurt (Supabase EU-Region), kein US-Cloud-Risiko
3. **Wöchentlicher Excel-Export**: jeden Sonntag wird automatisch unsere alte Excel-Datei generiert
   → "Ihr seid zu keinem Zeitpunkt von der App abhängig. Falls TSK morgen sagt 'wir hören auf' — wir haben die Excel."

## 9 · Kosten & nächster Schritt (1 Min)

> "Heutiger Stand: ~CHF 1.25/Monat (nur die Domain)."
> "Wenn TSK voll umsteigt mit allen 75 TL/DM: ~CHF 45/Monat."
>
> "Was wir jetzt brauchen: dein Ja, dass wir das **Soft-Live** schalten. Drei TL/DM testen 4 Wochen mit, danach Entscheidung über Roll-out auf alle 75."

## Q&A — vorbereitete Antworten

| Frage | Antwort |
|---|---|
| Was wenn die App ausfällt? | Wöchentlicher Excel-Export im alten Format ist immer da. Letzter Stand max. 7 Tage alt. |
| DSG-konform? | Ja, EU-Region. AVV mit Supabase Standard-Template wird unterzeichnet. |
| Wer kann was sehen? | Dispatcher = alles. TL/DM = eigener Saldo, alle Kurse, fremde Saldi nicht. |
| Was wenn ich ausfalle? | Standard React + Supabase — jeder Web-Entwickler kann übernehmen. Code ist auf GitHub. |
| Mobile? | Ja — Web-App lässt sich als Icon auf den Home-Screen legen, läuft wie eine App. iPad und iPhone getestet. |
| Anpassungen? | Vergütungssätze sind editierbar (kommt in v1.5). Skills sind klickbar editierbar (jetzt schon). |
| Was kostet eine native App im App-Store? | Aktuell PWA — wenn TSK eine native iOS-App will, ca. 3 Monate Mehraufwand + CHF 99/Jahr Apple-Developer. Erstmal nicht nötig. |

## Notfall-Plan

Falls Live-App während Demo ausfällt:
- Backup-Tab: lokal `npm run dev` mit lokalem Supabase laufen lassen
- Backup-Backup: Screenshots der wichtigsten Screens in Keynote bereithalten
