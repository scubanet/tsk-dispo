import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'node:path'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  test: {
    globals: true,
    environment: 'happy-dom',
    setupFiles: [],
    // Vitest must NOT pick up Playwright e2e specs — they use `test()` / `test.describe()`
    // from @playwright/test, not Vitest's. Without this exclude, `npm test` (vitest run)
    // crashes with "Playwright Test did not expect test() to be called here".
    exclude: [
      '**/node_modules/**',
      '**/dist/**',
      '**/tests/e2e/**',
      '**/playwright.config.ts',
    ],
  },
})
