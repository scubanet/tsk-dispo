// Global Vitest setup.
//
// Without this, @testing-library renders accumulate in the shared happy-dom
// document between tests in the same file → "Found multiple elements" errors
// across the suite (and a red `npm test`, which blocks the deploy workflow).
// Registering cleanup() after every test isolates each render.
import { afterEach } from 'vitest'
import { cleanup } from '@testing-library/react'

afterEach(() => {
  cleanup()
})
