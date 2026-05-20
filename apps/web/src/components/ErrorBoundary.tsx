import { Component, type ErrorInfo, type ReactNode } from 'react'

/**
 * Top-level ErrorBoundary. Catches any thrown render in the React tree below
 * `<BrowserRouter>` and renders a recoverable fallback instead of the dreaded
 * white screen.
 *
 * Strategy:
 * - `getDerivedStateFromError` flips state to error mode on the next render.
 * - `componentDidCatch` logs through `os.Logger`-style structured logging
 *   (gated to dev — production should wire a real telemetry sink, e.g. Sentry).
 * - The fallback offers two recovery paths:
 *     a) Reset — clears the error state, re-renders the children. Works when
 *        the error was transient (a stale prop, a failed async).
 *     b) Reload — `window.location.reload()`. Works when the error is in the
 *        app shell itself.
 * - Error details (message + stack) collapse into a `<details>` element so
 *   curious users can copy/paste; default-collapsed.
 *
 * Styling is intentionally inline — the boundary must work even if the CSS
 * pipeline itself broke during the offending render.
 */

interface Props {
  children: ReactNode
}

interface State {
  hasError: boolean
  error: Error | null
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false, error: null }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error }
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo): void {
    if (import.meta.env.DEV) {
      console.error('[ErrorBoundary] uncaught render error', error, errorInfo)
    } else {
      // Production: minimal logging, no PII / stack leaked to user-visible console.
      // Wire to Sentry / telemetry when available.
      console.error('[ErrorBoundary]', error.name, error.message)
    }
  }

  private handleReset = (): void => {
    this.setState({ hasError: false, error: null })
  }

  private handleReload = (): void => {
    window.location.reload()
  }

  render(): ReactNode {
    if (!this.state.hasError) return this.props.children

    return (
      <div
        role="alert"
        aria-live="assertive"
        style={{
          minHeight: '100dvh',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          padding: 24,
          fontFamily:
            'system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
          color: '#1a1a1a',
          background: '#fafafa',
        }}
      >
        <div
          style={{
            maxWidth: 480,
            width: '100%',
            padding: '32px 28px',
            borderRadius: 12,
            background: '#ffffff',
            boxShadow: '0 4px 24px rgba(0, 0, 0, 0.08)',
            border: '1px solid rgba(0, 0, 0, 0.06)',
          }}
        >
          <h1
            style={{
              margin: 0,
              fontSize: 20,
              fontWeight: 600,
              letterSpacing: '-0.01em',
            }}
          >
            Etwas ist schiefgelaufen.
          </h1>
          <p
            style={{
              marginTop: 12,
              marginBottom: 24,
              fontSize: 14,
              lineHeight: 1.55,
              color: '#555',
            }}
          >
            Die App hat einen unerwarteten Fehler erwischt. Du kannst es noch einmal versuchen — oder die Seite komplett neu laden, falls der Fehler bleibt.
          </p>

          <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
            <button
              type="button"
              onClick={this.handleReset}
              style={{
                flex: '1 1 160px',
                padding: '10px 16px',
                borderRadius: 8,
                border: '1px solid #0A84FF',
                background: '#0A84FF',
                color: '#fff',
                fontSize: 14,
                fontWeight: 600,
                cursor: 'pointer',
              }}
            >
              Erneut versuchen
            </button>
            <button
              type="button"
              onClick={this.handleReload}
              style={{
                flex: '1 1 160px',
                padding: '10px 16px',
                borderRadius: 8,
                border: '1px solid rgba(0,0,0,0.15)',
                background: '#fff',
                color: '#1a1a1a',
                fontSize: 14,
                fontWeight: 600,
                cursor: 'pointer',
              }}
            >
              Seite neu laden
            </button>
          </div>

          {this.state.error && (
            <details
              style={{
                marginTop: 24,
                fontSize: 12,
                color: '#666',
                cursor: 'pointer',
              }}
            >
              <summary style={{ outline: 'none' }}>Technische Details</summary>
              <pre
                style={{
                  marginTop: 8,
                  padding: 12,
                  borderRadius: 8,
                  background: '#f3f3f3',
                  color: '#333',
                  fontSize: 11,
                  lineHeight: 1.5,
                  overflowX: 'auto',
                  whiteSpace: 'pre-wrap',
                  wordBreak: 'break-word',
                }}
              >
                {this.state.error.name}: {this.state.error.message}
                {this.state.error.stack && '\n\n' + this.state.error.stack}
              </pre>
            </details>
          )}
        </div>
      </div>
    )
  }
}
