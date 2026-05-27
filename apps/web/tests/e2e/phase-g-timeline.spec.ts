/**
 * E2E: Phase G Phase 2 — User loggt eine Notiz im V2 Detail-Panel
 *      via EventComposer und sieht sie in der Timeline.
 *      Reload bestätigt Persistierung.
 *
 * Preconditions: dev server running, user authenticated, Test-Contact existiert
 *                mit dem Namen aus E2E_TEST_CONTACT_NAME (Default: 'Hugo Eugster').
 * Auth: Requires SUPABASE_TEST_TOKEN (gleiches Pattern wie übrige Specs).
 *
 * Cleanup nach dem Run (manuell via SQL):
 *   DELETE FROM contact_events WHERE summary LIKE 'e2e-%';
 */

import { test, expect, type Page } from '@playwright/test'

const TEST_CONTACT_NAME = process.env['E2E_TEST_CONTACT_NAME'] ?? 'Hugo Eugster'

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

test.describe('Phase G — V2 Timeline Log-Note', () => {
  test.skip(
    !process.env['SUPABASE_TEST_TOKEN'],
    'Requires SUPABASE_TEST_TOKEN env var.',
  )

  test('logged Notiz via V2 Panel persistiert über Reload', async ({ page }) => {
    const authed = await loginWithStoredSession(page)
    if (!authed) test.skip(true, 'No auth token')

    // Aktiviere crm_v2 Flag via URL param (persistiert in localStorage)
    await page.goto('/?crm_v2=1')

    // Navigiere zu Adressbuch
    await page.goto('/contacts')

    // Klick den Test-Contact in der Liste
    await page
      .getByText(new RegExp(TEST_CONTACT_NAME, 'i'))
      .first()
      .click()

    // V2 Panel sollte gemountet sein
    // (properties-sidebar-placeholder ist V2-spezifischer Marker)
    await expect(
      page.getByTestId('properties-sidebar-placeholder'),
    ).toBeVisible({ timeout: 8_000 })

    // Klick "Notiz" im EventComposer (segmented-control button).
    // Da auch ein Filter-Chip mit Text "Notiz" in der Timeline existiert,
    // scope mit .first() auf den Composer-Bereich (oberhalb der Timeline).
    await page.getByRole('button', { name: 'Notiz' }).first().click()

    const stamp = `e2e-${Date.now()}`
    await page.getByPlaceholder(/Titel der Notiz/i).fill(stamp)
    await page.getByPlaceholder(/Text/).fill('e2e body')
    await page.getByRole('button', { name: /Speichern/i }).click()

    // Note erscheint in Timeline
    await expect(page.getByText(stamp)).toBeVisible({ timeout: 5_000 })

    // Reload + Persistenz prüfen
    await page.reload()
    await expect(page.getByText(stamp)).toBeVisible({ timeout: 5_000 })

    // Note: Cleanup der Test-Notiz erfolgt manuell via SQL nach dem Run
    // (oder wird als Rauschen akzeptiert — events-Log ist append-only).
    // Cleanup-Query:
    //   DELETE FROM contact_events WHERE summary LIKE 'e2e-%';
  })
})
