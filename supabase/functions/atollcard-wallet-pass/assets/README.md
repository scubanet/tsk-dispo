# AtollCard Wallet-Pass Assets

Apple-required:
- icon.png       29 × 29
- icon@2x.png    58 × 58
- icon@3x.png    87 × 87
- logo.png       max 160 × 50
- logo@2x.png    max 320 × 100
- logo@3x.png    max 480 × 150

Alle PNG, transparent background, sRGB.

Quelle: ATOLL-Logo-SVG aus `apps/web/src/components/Logo.tsx` oder vom
Dominik-Brand-Kit. Bei Updates: alle 6 Dateien neu rendern, sonst rendert
Wallet auf verschiedenen iOS-Devices unterschiedlich.

Placeholder-Generation (für Implementer): 1×1 transparente PNGs werden
mit `sips`-Skalierung auf die korrekten Dimensionen gestreckt — Wallet
akzeptiert sie, sehen aber unbrauchbar aus. Vor Production durch echte
Assets ersetzen.
