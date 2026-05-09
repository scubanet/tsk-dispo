/**
 * E2E: Create a new contact via AddressbookScreen
 *
 * Preconditions: dev server running at http://localhost:5173, user authenticated.
 * Auth note: The app uses Magic-Link (email-only) auth via Supabase. There is
 * no password-based flow available, so tests that need a real session must be
 * run against a seeded local Supabase instance with service-role bypass, or
 * by injecting a session token via localStorage before navigation.
 *
 * These tests are marked test.skip until an auth fixture is available.
 * The test bodies are fully written so they run immediately once auth is wired.
 */

import { test, expect, type Page } from '@playwright/test'

// ---------------------------------------------------------------------------
// Auth helper — inject a pre-issued Supabase session so we skip Magic-Link
// ---------------------------------------------------------------------------
async function loginWithStoredSession(page: Page): Promise<boolean> {
  // If SUPABASE_TEST_TOKEN env var is set, inject it as a Supabase session.
  // Otherwise the test will skip itself below.
  const token = process.env['SUPABASE_TEST_TOKEN']
  if (!token) return false

  await page.goto('/')
  await page.evaluate((t: string) => {
    const key = `sb-${location.hostname}-auth-token`
    localStorage.setItem(key, JSON.stringify({ access_token: t, token_type: 'bearer' }))
  }, token)
  return true
}

// ---------------------------------------------------------------------------

test.describe('Adressbuch — Kontakt erstellen', () => {
  test.skip(
    !process.env['SUPABASE_TEST_TOKEN'],
    'Requires SUPABASE_TEST_TOKEN env var pointing to a valid service-role or test-user session.',
  )

  test('öffnet CreateContactSheet, füllt Formular, erstellt Schüler-Kontakt', async ({ page }) => {
    const authed = await loginWithStoredSession(page)
    if (!authed) test.skip(true, 'No auth token')

    await page.goto('/contacts')

    // The "Neu" button opens CreateContactSheet
    await page.getByRole('button', { name: 'Neu' }).click()

    // Drawer should be visible
    await expect(page.getByRole('heading', { name: /Neuer Kontakt/i })).toBeVisible()

    // Fill person form fields
    await page.getByPlaceholder('Max').fill('Erika')
    await page.getByPlaceholder('Mustermann').fill('Musterfrau')
    await page.getByPlaceholder('max@example.com').fill('erika.musterfrau@example.com')

    // Check the "Schüler" role checkbox
    await page.getByRole('checkbox', { name: 'Schüler' }).check()
    await expect(page.getByRole('checkbox', { name: 'Schüler' })).toBeChecked()

    // Submit
    await page.getByRole('button', { name: 'Erstellen' }).click()

    // ContactDetailPanel should open for the new contact
    await expect(page.getByText('Musterfrau, Erika')).toBeVisible({ timeout: 10_000 })
    // Schüler role badge visible in header
    await expect(page.getByText('Schüler')).toBeVisible()
  })
})
