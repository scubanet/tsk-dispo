/**
 * ThemeProvider — placeholder for future light/dark mode.
 *
 * Right now we ship light only. The provider exists so:
 *   1. Components can read theme state without depending on a global.
 *   2. Adding dark mode later is a one-file change.
 *
 * A `data-theme` attribute on <html> lets CSS swap variable values.
 */

import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'

type Theme = 'light' | 'dark'

interface ThemeContextValue {
  theme: Theme
  setTheme: (theme: Theme) => void
}

const ThemeContext = createContext<ThemeContextValue | null>(null)

export interface ThemeProviderProps {
  children: ReactNode
  defaultTheme?: Theme
}

export function ThemeProvider({ children, defaultTheme = 'light' }: ThemeProviderProps) {
  const [theme, setTheme] = useState<Theme>(defaultTheme)

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme)
  }, [theme])

  return (
    <ThemeContext.Provider value={{ theme, setTheme }}>
      {children}
    </ThemeContext.Provider>
  )
}

export function useTheme(): ThemeContextValue {
  const ctx = useContext(ThemeContext)
  if (!ctx) {
    // Allow components to be used outside the provider — fall back to light.
    return { theme: 'light', setTheme: () => undefined }
  }
  return ctx
}
