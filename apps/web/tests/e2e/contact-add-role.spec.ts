/**
 * E2E: Add a role to an existing contact via the ⋯ → Rollen verwalten menu.
 *
 * Preconditions: dev server running, user authenticated, at least one contact exists.
 * Auth: Same Magic-Link constraint as other specs — requires SUPABASE_TEST_TOKEN.
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

test.describe('Kontakt — Rolle hinzufügen', () => {
  test.skip(
    !process.env['SUPABASE_TEST_TOKEN'],
    'Requires SUPABASE_TEST_TOKEN env var.',
  )

  test('öffnet Rollen verwalten, aktiviert Newsletter-Rolle, speichert', async ({ page }) => {
    const authed = await loginWithStoredSession(page)
    if (!authed) test.skip(true, 'No auth token')

    await page.goto('/contacts')

    // Click the first contact in the list
    const firstItem = page.locator('.master-list__item').first()
    await firstItem.click()

    // ContactDetailPanel opens — wait for the header
    await expect(page.locator('.contact-header')).toBeVisible({ timeout: 8_000 })

    // Open the ⋯ more-menu
    await page.getByRole('button', { name: /⋯|Mehr|More/i }).click()

    // Click "Rollen verwalten"
    await page.getByRole('menuitem', { name: 'Rollen verwalten' }).click()

    // RoleManagerSheet drawer opens
    await expect(page.getByRole('heading', { name: /Rollen/i })).toBeVisible()

    // Check the "Newsletter" role (assumed not yet active)
    const newsletterCheckbox = page.getByRole('checkbox', { name: 'Newsletter' })
    if (!(await newsletterCheckbox.isChecked())) {
      await newsletterCheckbox.check()
    }
    await expect(newsletterCheckbox).toBeChecked()

    // Save
    await page.getByRole('button', { name: /Speichern/i }).click()

    // Drawer should close and the badge should appear in the contact header
    await expect(page.locator('.contact-header')).toContainText('Newsletter', { timeout: 8_000 })
  })
})
