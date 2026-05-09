/**
 * E2E: GDPR-Löschung (PII anonymise) flow.
 *
 * Flow:
 *   1. Create a temporary contact with a unique email.
 *   2. Open its detail panel.
 *   3. Via ⋯ → "GDPR-Löschung (PII entfernen)" → accept confirm dialog.
 *   4. Assert display_name is now "Gelöscht" and primary_email is empty.
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

test.describe('Kontakt — GDPR-Löschung', () => {
  test.skip(
    !process.env['SUPABASE_TEST_TOKEN'],
    'Requires SUPABASE_TEST_TOKEN env var.',
  )

  test('erstellt temporären Kontakt, führt GDPR-Löschung durch, prüft Anonymisierung', async ({ page }) => {
    const authed = await loginWithStoredSession(page)
    if (!authed) test.skip(true, 'No auth token')

    const uniqueEmail = `gdpr-test-${Date.now()}@example.com`

    await page.goto('/contacts')

    // 1. Create a temporary contact ─────────────────────────────────────────
    await page.getByRole('button', { name: 'Neu' }).click()
    await expect(page.getByRole('heading', { name: /Neuer Kontakt/i })).toBeVisible()

    await page.getByPlaceholder('Max').fill('GDPR')
    await page.getByPlaceholder('Mustermann').fill('Testperson')
    await page.getByPlaceholder('max@example.com').fill(uniqueEmail)
    await page.getByRole('button', { name: 'Erstellen' }).click()

    // Wait for the ContactDetailPanel to open
    await expect(page.getByText('Testperson, GDPR')).toBeVisible({ timeout: 10_000 })

    // 2. Open ⋯ menu ─────────────────────────────────────────────────────────
    await page.getByRole('button', { name: /⋯|Mehr|More/i }).click()

    // 3. Accept the browser confirm dialog BEFORE clicking (register handler first)
    page.on('dialog', (dialog) => void dialog.accept())

    // 4. Click GDPR-Löschung ─────────────────────────────────────────────────
    await page.getByRole('menuitem', { name: /GDPR-Löschung/i }).click()

    // 5. Assert anonymisation ────────────────────────────────────────────────
    // display_name should become "Gelöscht" (set by gdpr_anonymize_contact RPC)
    await expect(page.locator('.contact-header')).toContainText('Gelöscht', { timeout: 10_000 })

    // Primary email field should be empty
    await page.getByRole('tab', { name: 'Übersicht' }).click()
    const emailSection = page.locator('section').filter({ hasText: 'E-Mail' })
    await expect(emailSection).not.toContainText('@')
  })
})
