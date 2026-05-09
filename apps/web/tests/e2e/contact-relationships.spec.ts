/**
 * E2E: Add a relationship to an organization contact via the Mitglieder tab.
 *
 * Flow: open an org contact → Mitglieder tab → "+ Hinzufügen" →
 *       AddRelationshipSheet → search for a person → select → works_at → save →
 *       assert the new row appears in the members list.
 *
 * Preconditions:
 *   - Dev server running, user authenticated.
 *   - At least one organization contact exists (use ?view=orgs to filter).
 *   - At least one person contact exists to link.
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

test.describe('Kontakt — Beziehung hinzufügen (Mitglieder-Tab)', () => {
  test.skip(
    !process.env['SUPABASE_TEST_TOKEN'],
    'Requires SUPABASE_TEST_TOKEN env var.',
  )

  test('öffnet Organisation, Mitglieder-Tab, fügt works_at-Beziehung hinzu', async ({ page }) => {
    const authed = await loginWithStoredSession(page)
    if (!authed) test.skip(true, 'No auth token')

    // Navigate to organisations view
    await page.goto('/contacts?view=orgs')

    // Click the first org in the list
    const firstOrg = page.locator('.master-list__item').first()
    await firstOrg.click()
    await expect(page.locator('.contact-header')).toBeVisible({ timeout: 8_000 })

    // Navigate to the Mitglieder tab
    await page.getByRole('tab', { name: 'Mitglieder' }).click()

    // Click the "+ Hinzufügen" button in the tab
    await page.getByRole('button', { name: /Hinzufügen|\+/i }).first().click()

    // AddRelationshipSheet should open
    await expect(page.getByRole('heading', { name: /Beziehung|Mitglied/i })).toBeVisible()

    // Search for a person
    const searchInput = page.getByPlaceholder(/Suchen|Name/i).first()
    await searchInput.fill('a')
    await page.waitForTimeout(600) // debounce

    // Select the first result
    const firstResult = page.locator('.search-result-item, [role="option"]').first()
    await firstResult.waitFor({ state: 'visible', timeout: 6_000 })
    await firstResult.click()

    // Relationship kind selector — choose "arbeitet bei" (works_at)
    const kindSelect = page.getByRole('combobox')
    await kindSelect.selectOption('works_at')

    // Save
    await page.getByRole('button', { name: /Speichern|Hinzufügen/i }).click()

    // The member row should now appear in the Mitglieder list
    await expect(page.locator('.members-list__item').first()).toBeVisible({ timeout: 8_000 })
  })
})
