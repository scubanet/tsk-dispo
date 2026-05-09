/**
 * E2E: Inline-edit the Notizen field in the Übersicht tab,
 *      then verify an UPDATE audit entry appears.
 *
 * Preconditions: dev server running, user authenticated, at least one contact exists.
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

test.describe('Kontakt — Inline-Edit Notizen + Audit', () => {
  test.skip(
    !process.env['SUPABASE_TEST_TOKEN'],
    'Requires SUPABASE_TEST_TOKEN env var.',
  )

  test('bearbeitet das Notizen-Feld inline und prüft Audit-Tab auf UPDATE-Eintrag', async ({ page }) => {
    const authed = await loginWithStoredSession(page)
    if (!authed) test.skip(true, 'No auth token')

    await page.goto('/contacts')

    // Open the first contact
    const firstItem = page.locator('.master-list__item').first()
    await firstItem.click()
    await expect(page.locator('.contact-header')).toBeVisible({ timeout: 8_000 })

    // Ensure we're on the Übersicht tab
    await page.getByRole('tab', { name: 'Übersicht' }).click()

    // Find the Notizen inline field and click it to start editing
    const notesSection = page.locator('section').filter({ hasText: 'Notizen' })
    await notesSection.click()

    // A textarea or input should now be focused
    const noteInput = notesSection.locator('textarea, input[type="text"]').first()
    await noteInput.waitFor({ state: 'visible', timeout: 4_000 })
    await noteInput.fill(`E2E-Testnotiz ${Date.now()}`)

    // Commit by pressing Meta+Enter (macOS) or Tab to blur
    await noteInput.press('Meta+Enter')

    // Wait for saving indicator to disappear (no spinner / button text reverts)
    await page.waitForTimeout(1_500)

    // Reload the contact to verify persistence: close panel and reopen
    await page.getByRole('button', { name: /Schliessen|×/i }).click()
    await firstItem.click()
    await expect(page.locator('.contact-header')).toBeVisible({ timeout: 8_000 })

    await page.getByRole('tab', { name: 'Übersicht' }).click()
    await expect(page.locator('section').filter({ hasText: 'Notizen' })).toContainText('E2E-Testnotiz')

    // Switch to Audit tab and assert at least one UPDATE entry
    await page.getByRole('tab', { name: 'Audit' }).click()
    await expect(page.locator('.audit-list')).toBeVisible({ timeout: 8_000 })
    await expect(page.locator('.audit-op--update').first()).toBeVisible()
  })
})
