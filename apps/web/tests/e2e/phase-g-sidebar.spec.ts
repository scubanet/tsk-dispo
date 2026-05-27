/**
 * E2E: Phase G Phase 3 — User öffnet einen Contact im V2-Panel, sieht die
 *      Properties-Sidebar, editiert das Telefon-Feld inline und verifiziert
 *      dass der neue Wert über einen Reload persistiert.
 *
 * Preconditions: dev server running, user authenticated, Test-Contact
 *                existiert mit dem Namen aus E2E_TEST_CONTACT_NAME
 *                (Default: 'Hugo Eugster').
 * Auth: Requires SUPABASE_TEST_TOKEN (gleiches Pattern wie übrige Specs).
 *
 * Cleanup nach dem Run: nichts zu räumen — der Phone-Update ist destructive
 * und wird vom nächsten Test-Run einfach überschrieben. Wenn der ursprüngliche
 * Phone-Wert wichtig ist, manuell via SQL zurücksetzen:
 *   UPDATE contacts SET primary_phone = '<original>' WHERE display_name = 'Hugo Eugster';
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

test.describe('Phase G — V2 Properties-Sidebar Inline-Edit', () => {
  test.skip(
    !process.env['SUPABASE_TEST_TOKEN'],
    'Requires SUPABASE_TEST_TOKEN env var.',
  )

  test('editiert das Telefon-Feld inline in der Sidebar und persistiert über Reload', async ({ page }) => {
    const authed = await loginWithStoredSession(page)
    if (!authed) test.skip(true, 'No auth token')

    // Aktiviere crm_v2 Flag via URL param (persistiert in localStorage).
    await page.goto('/?crm_v2=1')

    // Navigiere zu Adressbuch.
    await page.goto('/contacts')

    // Klick den Test-Contact in der Liste.
    await page
      .getByText(new RegExp(TEST_CONTACT_NAME, 'i'))
      .first()
      .click()

    // V2 Properties-Sidebar sollte gemountet sein (Phase 3 — Placeholder
    // wurde ersetzt, data-testid heisst jetzt `properties-sidebar`).
    const sidebar = page.getByTestId('properties-sidebar')
    await expect(sidebar).toBeVisible({ timeout: 8_000 })

    // Scope alle weiteren Selektoren auf die Sidebar, um Kollisionen
    // mit Header / Timeline / Edit-Sheet zu vermeiden.
    // Die ContactSection (id="contact") ist defaultOpen=true; Telefon ist
    // das zweite EditableField. EditableField rendert im Display-Mode einen
    // <button>, im Edit-Mode ein <input type="tel">.
    const telefonField = sidebar
      .locator('div')
      .filter({ has: page.locator('text=Telefon') })
      .first()

    // Klick auf den Wert-Button neben dem "Telefon"-Label öffnet den
    // Edit-Mode. Wir scopen via Field-Wrapper + Role=button.
    await telefonField.getByRole('button').first().click()

    // Input mit type="tel" sollte jetzt sichtbar sein. Die ContactSection
    // hat nur ein einziges tel-Feld (Phone), also `.first()` ist sicher.
    const phoneInput = sidebar.locator('input[type="tel"]').first()
    await expect(phoneInput).toBeVisible({ timeout: 4_000 })

    // Generiere einen plausiblen, stempel-eindeutigen Wert.
    const stamp = `+417911${Date.now() % 100_000}`
    await phoneInput.fill(stamp)
    await page.keyboard.press('Enter')

    // Nach commit: Input verschwindet, Display-Button zeigt den neuen Wert.
    await expect(sidebar.getByText(stamp)).toBeVisible({ timeout: 5_000 })

    // Reload + Persistenz prüfen.
    await page.reload()

    // Nach Reload: Contact-Panel neu mounten — Sidebar wieder sichtbar.
    await expect(page.getByTestId('properties-sidebar')).toBeVisible({ timeout: 8_000 })
    await expect(page.getByTestId('properties-sidebar').getByText(stamp)).toBeVisible({
      timeout: 5_000,
    })
  })
})
