/**
 * E2E: Phase G Phase 4 Task 10 — User selektiert drei Contacts im Adressbuch,
 *      vergibt den Bulk-Tag „vip" via Bulk-Action-Bar und verifiziert, dass
 *      der Tag nach einem Reload an allen drei Contacts persistiert.
 *
 * Preconditions: dev server running, user authenticated, Adressbuch hat
 *                mindestens 3 Body-Rows mit eindeutigen `display_name`-Werten.
 * Auth: Requires SUPABASE_TEST_TOKEN (gleiches Pattern wie übrige Specs).
 *
 * Cleanup nach dem Run (manuell via SQL):
 *   UPDATE contacts SET tags = array_remove(tags, 'vip') WHERE 'vip' = ANY(tags);
 *
 * ODER falls das Test-Tag isoliert sein soll: vor dem Run das Tag-Label im
 * AddressbookBulkActionBar / AddressbookFilterBar auf `e2e_test` tauschen
 * (Code-Change), dann filtert das Cleanup auf das exklusive Tag.
 *
 * Idempotenz: der `add_tags`-Pfad in useBulkContactMutation deduped per
 * UNIQUE-Set, ein erneuter Lauf bei bereits getagten Contacts ist harmlos.
 *
 * Selektor-Strategie:
 *   • Body-Checkboxes via `input[type="checkbox"][aria-label^="Auswählen "]`
 *     (Header-Checkbox hat exakt `aria-label="Alle auswählen"`, kollidiert
 *     daher nicht mit dem Präfix-Match „Auswählen " + Name).
 *   • Bulk-Bar-Container über `data-testid="addressbook-bulk-action-bar"`.
 *   • Tag-Option im Dropdown via `aria-label="VIP"` an der `<input>`-Checkbox.
 *   • Sidebar-Tag-Chip via `aria-label="Tag vip entfernen"` (TagsSection-Pattern).
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

test.describe('Phase G Phase 4 — Bulk-Tag „vip" auf 3 Contacts', () => {
  test.skip(
    !process.env['SUPABASE_TEST_TOKEN'],
    'Requires SUPABASE_TEST_TOKEN env var.',
  )

  test('selektiert 3 Contacts, vergibt vip-Tag via Bulk-Bar und persistiert nach Reload', async ({ page }) => {
    const authed = await loginWithStoredSession(page)
    if (!authed) test.skip(true, 'No auth token')

    // crm_v2 Flag aktivieren (für Konsistenz mit den anderen Phase-G-Specs;
    // das Adressbuch selbst hängt nicht direkt davon ab, aber das V2-Panel
    // beim Detail-Click schon).
    await page.goto('/?crm_v2=1')

    // Adressbuch laden.
    await page.goto('/contacts')

    // Tabelle ist gerendert sobald der Screen-Header sichtbar ist.
    await expect(page.getByText('Adressbuch')).toBeVisible({ timeout: 8_000 })

    // ── Drei Rows selektieren ──────────────────────────────────────────
    // Body-Checkboxes haben `aria-label="Auswählen <display_name>"` (T6).
    // Wir nehmen die ersten drei in DOM-Reihenfolge — egal welche Contacts
    // das sind, der Test braucht nur 3 stabile Identitäten.
    const bodyCheckboxes = page.locator('input[type="checkbox"][aria-label^="Auswählen "]')

    // Sanity: mindestens 3 Rows müssen sichtbar sein.
    await expect(bodyCheckboxes.nth(2)).toBeVisible({ timeout: 8_000 })

    // Display-Namen für spätere Verifikation festhalten (aria-label-Suffix
    // ohne das „Auswählen "-Präfix).
    const selectedNames: string[] = []
    for (let i = 0; i < 3; i++) {
      const cb = bodyCheckboxes.nth(i)
      const label = (await cb.getAttribute('aria-label')) ?? ''
      const name = label.replace(/^Auswählen\s+/, '').trim()
      selectedNames.push(name)
      await cb.check()
    }
    expect(selectedNames).toHaveLength(3)

    // ── Bulk-Bar erscheint mit Counter „3 ausgewählt" ──────────────────
    const bulkBar = page.getByTestId('addressbook-bulk-action-bar')
    await expect(bulkBar).toBeVisible()
    await expect(bulkBar.getByText(/3 ausgewählt/)).toBeVisible()

    // ── + Tags ▾ Dropdown öffnen ───────────────────────────────────────
    await bulkBar.getByRole('button', { name: /\+ Tags/ }).click()

    // Tag-Menu sichtbar; VIP-Option per aria-label der Checkbox checken.
    const tagsMenu = bulkBar.getByRole('menu', { name: 'Tags hinzufügen' })
    await expect(tagsMenu).toBeVisible({ timeout: 4_000 })
    await tagsMenu.getByRole('checkbox', { name: 'VIP' }).check()

    // ── Anwenden ───────────────────────────────────────────────────────
    await tagsMenu.getByRole('button', { name: 'Anwenden' }).click()

    // Erfolg: das Tag-Menu schließt sich (onSuccess in runAction). Wir geben
    // der Mutation einen Moment, dann reloaden wir.
    await expect(tagsMenu).toBeHidden({ timeout: 6_000 })

    // ── Reload: Daten frisch aus DB ────────────────────────────────────
    await page.reload()
    await expect(page.getByText('Adressbuch')).toBeVisible({ timeout: 8_000 })

    // ── Verifikation: für jeden der drei Namen Contact öffnen und
    //    in der TagsSection den „vip"-Chip prüfen. ──────────────────────
    // TagsSection rendert pro Tag ein <button aria-label="Tag vip entfernen">
    // (siehe TagsSection.tsx). Wir scopen den Match auf die V2-Sidebar.
    for (const name of selectedNames) {
      // Den Row-Header über die zugehörige Body-Checkbox finden ist robuster
      // als ein blinder text-match auf den Namen (kollidiert mit Subtitle /
      // E-Mail-Cell).
      const rowCheckbox = page.locator(
        `input[type="checkbox"][aria-label="Auswählen ${name}"]`,
      )
      await expect(rowCheckbox).toBeVisible()

      // Row aktivieren = Click auf die zugehörige Row (parent `[role="row"]`).
      // Wir klicken bewusst nicht die Checkbox (die stoppt propagation und
      // selektiert nur), sondern eine Cell mit dem Namen-Text in derselben Row.
      const row = rowCheckbox.locator('xpath=ancestor::*[@role="row"][1]')
      await row.getByText(name, { exact: false }).first().click()

      // Sidebar gemountet — `vip`-Tag-Chip sichtbar.
      const sidebar = page.getByTestId('properties-sidebar')
      await expect(sidebar).toBeVisible({ timeout: 8_000 })
      await expect(
        sidebar.getByRole('button', { name: 'Tag vip entfernen' }),
      ).toBeVisible({ timeout: 5_000 })
    }
  })
})
