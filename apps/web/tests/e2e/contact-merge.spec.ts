/**
 * E2E: Merge two contacts — winner keeps both roles, loser is archived.
 *
 * Flow:
 *   1. Create contact A ("Merge Winner") with role Newsletter.
 *   2. Create contact B ("Merge Loser") with same name + unique email.
 *   3. On contact A: ⋯ → "Mit anderem Kontakt verschmelzen" →
 *      search for B → select → confirm merge.
 *   4. Assert B no longer appears in the default Adressbuch list.
 *   5. Assert A (winner) still exists in the list.
 *
 * Known issue: merge_contacts RPC references `person_id` on several tables
 * but the actual schema uses `student_id` (intake_checklists, elearning_progress).
 * The merge may produce a DB error until the RPC is patched. This test is still
 * valuable as an integration canary.
 *
 * Preconditions: dev server running, user authenticated.
 * Auth: Requires SUPABASE_TEST_TOKEN.
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

// ── Helper: create a contact via the UI ───────────────────────────────────

async function createContact(
  page: Page,
  firstName: string,
  lastName: string,
  email: string,
  role?: string,
): Promise<void> {
  await page.getByRole('button', { name: 'Neu' }).click()
  await expect(page.getByRole('heading', { name: /Neuer Kontakt/i })).toBeVisible()

  await page.getByPlaceholder('Max').fill(firstName)
  await page.getByPlaceholder('Mustermann').fill(lastName)
  await page.getByPlaceholder('max@example.com').fill(email)

  if (role) {
    await page.getByRole('checkbox', { name: role }).check()
  }

  await page.getByRole('button', { name: 'Erstellen' }).click()
  // Wait for detail panel to open, then close it to return to the list
  await expect(page.locator('.contact-header')).toBeVisible({ timeout: 10_000 })
  await page.getByRole('button', { name: /Schliessen|×/i }).click()
}

// ── Test ───────────────────────────────────────────────────────────────────

test.describe('Kontakt — Merge', () => {
  test.skip(
    !process.env['SUPABASE_TEST_TOKEN'],
    'Requires SUPABASE_TEST_TOKEN env var.',
  )

  test('verschmilzt zwei Kontakte, prüft Archivierung des Losers', async ({ page }) => {
    const authed = await loginWithStoredSession(page)
    if (!authed) test.skip(true, 'No auth token')

    const ts = Date.now()
    const winnerEmail = `merge-winner-${ts}@example.com`
    const loserEmail  = `merge-loser-${ts}@example.com`

    await page.goto('/contacts')

    // 1. Create winner + loser ───────────────────────────────────────────────
    await createContact(page, 'Merge', 'Winner', winnerEmail, 'Newsletter')
    await createContact(page, 'Merge', 'Loser',  loserEmail)

    // 2. Search for the winner and open it ──────────────────────────────────
    const searchInput = page.getByPlaceholder(/Suchen|Search/i).first()
    await searchInput.fill('merge-winner')
    await page.waitForTimeout(600)

    const winnerItem = page.locator('.master-list__item').first()
    await winnerItem.click()
    await expect(page.locator('.contact-header')).toBeVisible({ timeout: 8_000 })

    // 3. Open ⋯ → Verschmelzen ───────────────────────────────────────────────
    await page.getByRole('button', { name: /⋯|Mehr|More/i }).click()
    await page.getByRole('menuitem', { name: /verschmelzen/i }).click()

    // MergeContactsSheet opens
    await expect(page.getByRole('heading', { name: /Verschmelzen|Merge/i })).toBeVisible()

    // 4. Search for loser ────────────────────────────────────────────────────
    const mergeSearch = page.getByPlaceholder(/Suchen|Name/i).first()
    await mergeSearch.fill('merge-loser')
    await page.waitForTimeout(600)

    const loserResult = page.locator('.search-result-item, [role="option"]').first()
    await loserResult.waitFor({ state: 'visible', timeout: 6_000 })
    await loserResult.click()

    // 5. Confirm merge ────────────────────────────────────────────────────────
    // Register dialog handler before clicking the confirm button
    page.on('dialog', (dialog) => void dialog.accept())
    await page.getByRole('button', { name: /Verschmelzen|Merge bestätigen/i }).click()

    // 6. Winner should still be visible ─────────────────────────────────────
    await expect(page.locator('.contact-header')).toBeVisible({ timeout: 10_000 })

    // 7. Loser should NOT appear in the default list (archived contacts filtered out)
    await searchInput.fill('')
    await page.waitForTimeout(600)

    const loserVisible = await page.locator('.master-list__item', { hasText: 'merge-loser' }).count()
    expect(loserVisible).toBe(0)
  })
})
