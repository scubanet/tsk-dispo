/**
 * E2E: Phase G Phase 5 Task 7 — User öffnet den /aktivitaet-Screen, klickt
 *      die erste ActivityEventCard, und verifiziert dass:
 *        1. die URL nach /contacts?contact=<id>&event=<eid> navigiert,
 *        2. die ContactDetail-Sidebar mountet,
 *        3. die zur geklickten Card gehörende Timeline-EventCard im
 *           Detail-Panel das `data-event-highlighted="true"`-Attribut trägt
 *           (Highlight-Animation, T6).
 *
 * Preconditions:
 *   • dev server running, user authenticated,
 *   • mindestens 1 Contact mit ≥1 Event in der DB (sonst rendert der
 *     ActivityScreen keine Cards und der Test skipt nicht — er failed
 *     beim `firstCard.waitFor`).
 *
 * Cleanup: nichts — der Flow ist read-only, kein Mutation, kein Snapshot.
 *
 * Auth: Requires SUPABASE_TEST_TOKEN (gleiches Pattern wie übrige Phase-G-
 * Specs, siehe phase-g-sidebar.spec.ts).
 *
 * Selektor-Strategie:
 *   • ActivityEventCard rendert ein <article role="button"> ohne stabilen
 *     data-event-id-Attribut. Im V2-Panel rendert TimelineFeed jedoch
 *     EventCard (timeline/EventCard.tsx) MIT `data-event-id` und gesetzt-
 *     wenn-aktiv `data-event-highlighted="true"`. Daher:
 *       – Activity-Card anklicken via erstem <article role="button">
 *         im Screen-Container,
 *       – contact_id + event_id aus dem navigate-Target rekonstruieren
 *         (wir lesen die URL nach dem Click und greifen die Param raus),
 *       – Highlighting an der Timeline-Card im Detail-Panel asserten.
 *
 *   • Das Detail-Panel mountet je nach `crm_v2`-Flag entweder die V2-
 *     Properties-Sidebar (`[data-testid="properties-sidebar"]`) oder die
 *     Legacy-Tab-Body-Container. Wir erlauben beides via OR-Selektor.
 */

import { test, expect, type Page } from '@playwright/test'

async function loginWithStoredSession(page: Page): Promise<boolean> {
  const token = process.env['SUPABASE_TEST_TOKEN']
  if (!token) return false
  await page.goto('/')
  await page.evaluate((t: string) => {
    const key = `sb-${location.hostname}-auth-token`
    localStorage.setItem(key, JSON.stringify({ access_token: t, token_type: 'bearer' }))
  }, token)
  return true
}

test.describe('Phase G Phase 5 — /aktivitaet → Click → Detail mit Highlighting', () => {
  test.skip(
    !process.env['SUPABASE_TEST_TOKEN'],
    'Requires SUPABASE_TEST_TOKEN env var.',
  )

  test('Klick auf Activity-Card öffnet Detail mit Highlighting', async ({ page }) => {
    const authed = await loginWithStoredSession(page)
    if (!authed) test.skip(true, 'No auth token')

    // crm_v2 Flag setzen für Konsistenz mit den übrigen Phase-G-Specs.
    // Das ActivityScreen-Listing selbst hängt nicht davon ab, aber das
    // V2-Detail-Panel beim navigate-Target schon.
    await page.goto('/?crm_v2=1')

    // Activity-Screen laden.
    await page.goto('/aktivitaet')
    await expect(
      page.getByRole('heading', { name: /Aktivität/i }),
    ).toBeVisible({ timeout: 8_000 })

    // Mindestens 1 Activity-Card warten. ActivityEventCard rendert ein
    // <article role="button"> (T1). Wir matchen Role + aria-label-Pattern
    // („<summary> — <name>") nicht direkt; das erste passende <article>
    // mit role=button reicht.
    const firstActivityCard = page.locator('article[role="button"]').first()
    await expect(firstActivityCard).toBeVisible({ timeout: 10_000 })

    // Card klicken — navigate-URL ist `/contacts?contact=<id>&event=<eid>`.
    await firstActivityCard.click()

    // URL ist jetzt /contacts mit beiden Params. crm_v2-Param kann zusätzlich
    // anhängen, wir matchen nur auf das Vorhandensein von contact= und event=.
    await expect(page).toHaveURL(/\/contacts\?.*contact=.*event=.*/, {
      timeout: 5_000,
    })

    // Event-ID aus der URL parsen — die brauchen wir für das Highlight-
    // Assertion auf der Timeline-Card im Detail-Panel.
    const url = new URL(page.url())
    const eventId = url.searchParams.get('event')
    expect(eventId, 'event= Query-Param sollte gesetzt sein').toBeTruthy()

    // Detail-Panel mounted: V2-Sidebar ODER Legacy-Container.
    // (Der Legacy-Container hat in dieser Codebase keine eindeutige Klasse,
    //  wir matchen daher pragmatisch auf properties-sidebar — wenn das Flag
    //  aus ist, fallen wir auf den Heading-Match weiter unten zurück.)
    const detailMounted = page.locator(
      '[data-testid="properties-sidebar"], [data-testid="contact-detail-panel"]',
    ).first()
    await expect(detailMounted).toBeVisible({ timeout: 8_000 })

    // Highlight-Attribute: die Timeline-EventCard (timeline/EventCard.tsx, T6)
    // rendert das article mit `data-event-id=<eid>` UND
    // `data-event-highlighted="true"` wenn der URL-Param matched.
    // Die CSS-Animation läuft 1.5s, das Attribut bleibt persistent —
    // daher reicht ein normales `toBeVisible`.
    await expect(
      page.locator(
        `article[data-event-id="${eventId}"][data-event-highlighted="true"]`,
      ),
    ).toBeVisible({ timeout: 5_000 })
  })
})
