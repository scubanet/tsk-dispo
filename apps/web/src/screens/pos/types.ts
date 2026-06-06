// Geteilter Warenkorb-Typ + Netto-Berechnung. Pro Zeile auf 2 Stellen gerundet —
// deckungsgleich mit order_recalc (round(qty*unit_price*(1-discount_pct/100), 2)),
// damit der Beleg-Total exakt dem ausgestellten Rechnungstotal entspricht. >= 0 geklemmt.
export interface CartLine {
  variantId: string
  name: string
  sku: string | null
  unitPrice: number
  qty: number
  discountPct: number
  serialized: boolean
  serialUnitId: string | null
}

export function lineNet(l: CartLine): number {
  return Math.max(0, Math.round(l.qty * l.unitPrice * (1 - l.discountPct / 100) * 100) / 100)
}
