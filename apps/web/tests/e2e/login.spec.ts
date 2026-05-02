import { test, expect } from '@playwright/test'

test('login screen renders and accepts email', async ({ page }) => {
  await page.goto('/login')

  await expect(page.getByText('ATOLL')).toBeVisible()
  await expect(page.getByText(/Magic-Link an deine Email/)).toBeVisible()

  const input = page.getByPlaceholder('deine@email.ch')
  await input.fill('test@example.com')
  await page.getByRole('button', { name: /Magic-Link senden/ }).click()

  await expect(page.getByText('Link gesendet')).toBeVisible({ timeout: 10_000 })
})
