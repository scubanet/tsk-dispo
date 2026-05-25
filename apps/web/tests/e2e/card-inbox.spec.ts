/**
 * E2E: Public Card-Page → INSERT in card_leads → Web Inbox zeigt Lead
 * innert 2s (Realtime), Klick auf Importieren → Contact erscheint im Adressbuch.
 *
 * Voraussetzungen:
 *   - Test-DB mit einer existierenden Karte slug='dominik-cd'
 *   - Test-User credentials in .env.test (TEST_USER_EMAIL, TEST_USER_PASSWORD)
 */
import { test, expect } from '@playwright/test'

const TEST_EMAIL = `e2e+${Date.now()}@example.invalid`

test.describe('Card-Inbox E2E', () => {
  test('public form → inbox → import → adressbuch', async ({ page, context }) => {
    // 1. Public form
    await page.goto('/c/dominik-cd')
    await page.getByLabel(/vorname/i).fill('Edna E2E')
    await page.getByLabel(/email/i).fill(TEST_EMAIL)
    await page.getByLabel(/nachricht/i).fill('E2E test message')
    await page.getByRole('button', { name: /senden/i }).click()
    await expect(page.getByText(/danke/i)).toBeVisible()

    // 2. Switch to owner session and open Inbox
    const ownerPage = await context.newPage()
    await ownerPage.goto('/login')
    await ownerPage.getByLabel(/email/i).fill(process.env.TEST_USER_EMAIL!)
    await ownerPage.getByLabel(/passwort|password/i).fill(process.env.TEST_USER_PASSWORD!)
    await ownerPage.getByRole('button', { name: /anmelden|login/i }).click()
    await ownerPage.waitForURL(/heute/)

    await ownerPage.goto('/contacts/card-inbox?view=new')

    // 3. Lead taucht innert 2s auf (Realtime)
    const leadRow = ownerPage.getByText('Edna E2E')
    await expect(leadRow).toBeVisible({ timeout: 5000 })

    // 4. Detail öffnen + importieren
    await leadRow.click()
    ownerPage.on('dialog', async (d) => await d.accept())   // import-success alert
    await ownerPage.getByRole('button', { name: /importieren/i }).click()

    // 5. Browser navigiert zum Adressbuch mit dem neuen Contact
    await ownerPage.waitForURL(/\/contacts\?contact=/)
    await expect(ownerPage.getByText('Edna E2E')).toBeVisible()
  })
})
