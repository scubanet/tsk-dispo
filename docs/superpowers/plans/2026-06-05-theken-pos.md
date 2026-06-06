# Theken-POS (Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eine dedizierte Theken-Kasse (`/kasse`) mit Produkt-Grid, Warenkorb, Kundenauswahl + Laufkundschaft-Default, Barcode-Scan, %-Rabatt und druckbarem Beleg — auf dem bestehenden `pos_checkout`-RPC.

**Architecture:** Neuer React-Screen `PosScreen` mit lokalem Warenkorb-State, der den vorhandenen `pos_checkout(contact_id, lines, method, pay)`-RPC aufruft (Order → Rechnung → Zahlung → Lagerabgang). Backend nur minimal: ein idempotenter Laufkundschaft-Seed + `barcode` in der Katalog-Query. Rollen-Gating Dispatcher/Owner/CD (deckt den `is_dispatcher()/is_owner()`-Guard von `pos_checkout`).

**Tech Stack:** React 18 + TypeScript + Vite, `@tanstack/react-query`, Supabase (PostgREST + RPC), plain-CSS Foundation-Komponenten, react-i18next, pgTAP.

---

## Abweichung von der Spec (beim Plan-Schreiben entdeckt)

Spec §4/§5 sahen eine „Migration A" für Rabatt-Spalten + `pos_checkout`-Erweiterung vor. **Überflüssig:** `order_lines.discount_pct NUMERIC(5,2)` existiert bereits (`20260605090200_finance_core.sql:120`, CHECK 0–100), `order_recalc` wendet ihn an (`20260605090400_finance_rpcs.sql:46,64`), `invoice_issue` friert ihn in `invoice_lines` ein (`:168-171`), `pos_checkout` liest ihn (`20260605091100_m2_retail_rpcs.sql:176`), und der Frontend-Typ `CheckoutLine` hat `discount_pct?` (`financeQueries.ts:111`). **Folge:** keine Rabatt-Migration; `discount_chf` entfällt (YAGNI — %-Rabatt deckt die TL/DM-Matrix). Backend-Aufwand reduziert sich auf den Laufkundschaft-Seed (+ pgTAP, das die bestehende Rabatt-Anwendung absichert) und eine Katalog-Query-Erweiterung.

## File Structure

**Backend (Repo-Root):**
- Create `supabase/tests/pgtap/12_pos_walk_in_discount.sql` — sichert Laufkundschaft-Seed + Rabatt-Anwendung.
- Create `supabase/migrations/20260606000300_seed_walk_in_contact.sql` — idempotenter Laufkundschaft-Kontakt (Tag `walk_in`).

**Frontend (`apps/web/src/`):**
- Modify `lib/retailQueries.ts` — `barcode` in Katalog-Query + Typen.
- Create `lib/posQueries.ts` — Laufkundschaft-Resolver + Kontaktsuche.
- Create `hooks/usePos.ts` — React-Query-Hooks (Walk-in, Suche, Checkout).
- Create `screens/pos/types.ts` — `CartLine`-Typ (geteilt zwischen Screen + Panels).
- Create `screens/pos/BarcodeInput.tsx` — Scan-Feld.
- Create `screens/pos/ProductGrid.tsx` — Produkt-Karten-Grid.
- Create `screens/pos/CustomerPicker.tsx` — Kunden-Chip + Suche (Sheet).
- Create `screens/pos/CartPanel.tsx` — Warenkorb + Rabatt + Summen + Zahlart.
- Create `screens/pos/ReceiptView.tsx` — druckbarer Beleg.
- Create `screens/pos/PosScreen.tsx` — komponiert alles, hält den State.
- Create `styles/pos-print.css` — `@media print`-Regeln; in `main.tsx`/Screen importiert.
- Modify `App.tsx` — Lazy-Route `/kasse`.
- Modify `components/Sidebar.tsx` — `ITEMS`-Eintrag `/kasse`.
- Modify `screens/TodayScreen.tsx` — prominenter „Kasse"-Button (DispatcherToday).
- Modify `i18n/locales/de.json` + `en.json` — `pos.*` + `nav.pos`.

---

## Task 1: pgTAP — Laufkundschaft + Rabatt-Anwendung (failing test)

**Files:**
- Test: `supabase/tests/pgtap/12_pos_walk_in_discount.sql`

- [ ] **Step 1: Write the failing test**

Create `supabase/tests/pgtap/12_pos_walk_in_discount.sql`:

```sql
-- 12_pos_walk_in_discount.sql
-- (a) Laufkundschaft-Sammelkontakt (Tag walk_in) existiert (Seed-Migration 20260606000300).
-- (b) pos_checkout wendet discount_pct an: Rechnungstotal = Netto nach Rabatt.
-- (c) order_lines.discount_pct wird festgehalten.
BEGIN;
SELECT plan(4);

-- Dispatcher im geseedeten Tenant tsk-zrh (Muster wie 09_m2_inventory).
INSERT INTO auth.users (id, email) VALUES ('c0000000-0000-0000-0000-0000000000d1', 'pos@test.dev');
INSERT INTO public.contacts (id, kind, first_name, last_name)
  VALUES ('ca000000-0000-0000-0000-0000000000d1', 'person', 'Pos', 'Disp');
INSERT INTO public.instructors (id, name, padi_level, initials, role, auth_user_id)
  VALUES ('ca000000-0000-0000-0000-0000000000d1', 'PosDisp', 'OWSI', 'PD', 'dispatcher',
          'c0000000-0000-0000-0000-0000000000d1');
INSERT INTO public.contact_instructor (contact_id, auth_user_id, tenant_id)
  VALUES ('ca000000-0000-0000-0000-0000000000d1', 'c0000000-0000-0000-0000-0000000000d1',
          (SELECT id FROM public.tenants WHERE slug = 'tsk-zrh'));

-- Produkt + Variante (Preis 100) im Tenant tsk-zrh.
INSERT INTO public.products (id, tenant_id, name)
SELECT 'cb000000-0000-0000-0000-0000000000d1', id, 'Rabatt-Maske' FROM public.tenants WHERE slug = 'tsk-zrh';
INSERT INTO public.product_variants (id, tenant_id, product_id, sku, price)
SELECT 'cc000000-0000-0000-0000-0000000000d1', id, 'cb000000-0000-0000-0000-0000000000d1', 'RAB-1', 100
FROM public.tenants WHERE slug = 'tsk-zrh';

-- Kunde für die Rechnung.
INSERT INTO public.contacts (id, kind, first_name, last_name)
  VALUES ('cd000000-0000-0000-0000-0000000000d1', 'person', 'Rab', 'Att');

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub":"c0000000-0000-0000-0000-0000000000d1","role":"authenticated"}';

-- (a) Laufkundschaft-Kontakt existiert (aus der Seed-Migration).
SELECT is(
  (SELECT count(*)::int FROM public.contacts WHERE 'walk_in' = ANY(tags)),
  1, 'genau ein Laufkundschaft-Kontakt mit Tag walk_in'
);

-- (b)+(c) Verkauf 1× CHF 100 mit 25% Rabatt → Total CHF 75, discount_pct festgehalten.
SELECT lives_ok(
  $$ SELECT public.pos_checkout('cd000000-0000-0000-0000-0000000000d1',
       '[{"item_type":"product","item_ref_id":"cc000000-0000-0000-0000-0000000000d1","description":"Rabatt-Maske","quantity":1,"unit_price":100,"discount_pct":25}]'::jsonb,
       'cash', true) $$,
  'pos_checkout mit Rabatt läuft'
);
SELECT is(
  (SELECT total FROM public.invoices
    WHERE contact_id = 'cd000000-0000-0000-0000-0000000000d1' ORDER BY created_at DESC LIMIT 1),
  75.00::numeric, 'Rechnungstotal = 100 − 25% = 75'
);
SELECT is(
  (SELECT ol.discount_pct FROM public.order_lines ol
     JOIN public.orders o ON o.id = ol.order_id
    WHERE o.contact_id = 'cd000000-0000-0000-0000-0000000000d1' ORDER BY ol.created_at DESC LIMIT 1),
  25.00::numeric, 'order_lines.discount_pct = 25 festgehalten'
);

SELECT * FROM finish();
ROLLBACK;
```

- [ ] **Step 2: Run test to verify it fails**

Run: `supabase test db`
Expected: `12_pos_walk_in_discount.sql` FAILT bei Assertion (a) — „want 1, have 0" (Laufkundschaft-Seed fehlt noch). (b)/(c) sind bereits grün (Rabatt-Logik existiert). Alle übrigen Files bleiben grün.

- [ ] **Step 3: Commit (nur der Test)**

```bash
git add supabase/tests/pgtap/12_pos_walk_in_discount.sql
git commit -m "test(pos): walk-in contact + discount application (failing)"
```

---

## Task 2: Laufkundschaft-Seed-Migration (macht Task 1 grün)

**Files:**
- Create: `supabase/migrations/20260606000300_seed_walk_in_contact.sql`

- [ ] **Step 1: Migration schreiben**

Create `supabase/migrations/20260606000300_seed_walk_in_contact.sql`:

```sql
-- 20260606000300_seed_walk_in_contact.sql
-- Laufkundschaft-Sammelkontakt für den Theken-POS. pos_checkout verlangt eine
-- contact_id; Barverkäufe ohne Kundenkonto werden auf diesen Kontakt gebucht.
-- Markiert per Tag 'walk_in'; das Frontend löst die ID darüber auf. Idempotent
-- (legt nur an, wenn noch keiner existiert). contacts ist aktuell effektiv
-- single-tenant (TSK) → ein Eintrag genügt.
INSERT INTO public.contacts (kind, first_name, last_name, tags, source)
SELECT 'person', 'Laufkundschaft', '(Theke)', ARRAY['walk_in'], 'pos_seed'
WHERE NOT EXISTS (SELECT 1 FROM public.contacts WHERE 'walk_in' = ANY(tags));
```

- [ ] **Step 2: Syntax prüfen (Sandbox, kein lokaler PG)**

Run: `python3 -c "from pglast import parse_sql; parse_sql(open('supabase/migrations/20260606000300_seed_walk_in_contact.sql').read()); print('OK')"`
Expected: `OK`

- [ ] **Step 3: Reset + Test**

Run: `supabase db reset && supabase test db`
Expected: alle Files grün, inkl. `12_pos_walk_in_discount.sql` (4/4).

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260606000300_seed_walk_in_contact.sql
git commit -m "feat(pos): seed Laufkundschaft walk-in contact"
```

---

## Task 3: `barcode` in die Katalog-Query

**Files:**
- Modify: `apps/web/src/lib/retailQueries.ts:10-77`

- [ ] **Step 1: Typen + Select erweitern**

In `apps/web/src/lib/retailQueries.ts`:

`CatalogVariantRow` (um `barcode` ergänzen):
```ts
interface CatalogVariantRow {
  id: string
  sku: string | null
  barcode: string | null
  price: Num
  currency: string
  products: {
    id: string
    name: string
    brand: string | null
    model: string | null
    category_id: string | null
    reorder_point: Num
    serialized: boolean
  } | null
}
```

`CatalogItem` (um `barcode` ergänzen):
```ts
export interface CatalogItem {
  variant_id: string
  product_id: string
  name: string
  brand: string | null
  model: string | null
  sku: string | null
  barcode: string | null
  price: number
  currency: string
  on_hand: number
  reorder_point: number
  low: boolean
  serialized: boolean
  category_id: string | null
}
```

In `fetchCatalog`, den Select um `barcode` erweitern:
```ts
    supabase.from('product_variants')
      .select('id, sku, barcode, price, currency, products!inner(id, name, brand, model, category_id, reorder_point, serialized)')
      .eq('is_active', true),
```

Und im Map-Block `barcode: v.barcode,` ergänzen (direkt nach `sku: v.sku,`):
```ts
      sku: v.sku,
      barcode: v.barcode,
```

- [ ] **Step 2: Typecheck**

Run: `npm -w @tsk/web run typecheck`
Expected: keine Fehler (`ProductsScreen` nutzt `CatalogItem` weiter, neues optionales Feld bricht nichts).

- [ ] **Step 3: Commit**

```bash
git add apps/web/src/lib/retailQueries.ts
git commit -m "feat(pos): expose variant barcode in catalog query"
```

---

## Task 4: POS-Datenschicht — `posQueries.ts` + `usePos.ts`

**Files:**
- Create: `apps/web/src/lib/posQueries.ts`
- Create: `apps/web/src/hooks/usePos.ts`

- [ ] **Step 1: `posQueries.ts` schreiben**

Create `apps/web/src/lib/posQueries.ts`:

```ts
import { supabase } from '@/lib/supabase'

// Laufkundschaft-Sammelkontakt (Tag walk_in, per Seed-Migration angelegt).
export async function fetchWalkInContactId(): Promise<string | null> {
  const { data, error } = await supabase.from('contacts')
    .select('id').contains('tags', ['walk_in']).limit(1).maybeSingle()
  if (error) throw error
  return (data as { id: string } | null)?.id ?? null
}

export interface SellableContact { id: string; name: string }

// Kontaktsuche für die Kundenauswahl an der Kasse (Name/Anzeigename).
export async function searchSellableContacts(q: string): Promise<SellableContact[]> {
  const term = q.trim()
  if (term.length < 2) return []
  const { data, error } = await supabase.from('contacts')
    .select('id, display_name, first_name, last_name')
    .or(`display_name.ilike.%${term}%,first_name.ilike.%${term}%,last_name.ilike.%${term}%`)
    .is('archived_at', null)
    .limit(20)
  if (error) throw error
  return ((data ?? []) as Array<{ id: string; display_name: string | null; first_name: string | null; last_name: string | null }>)
    .map((c) => ({
      id: c.id,
      name: c.display_name ?? [c.first_name, c.last_name].filter(Boolean).join(' ') ?? '—',
    }))
}
```

- [ ] **Step 2: `usePos.ts` schreiben**

Create `apps/web/src/hooks/usePos.ts`:

```ts
import { useQuery, useMutation } from '@tanstack/react-query'
import { fetchWalkInContactId, searchSellableContacts } from '@/lib/posQueries'
import { posCheckout, type CheckoutLine } from '@/lib/financeQueries'

export function useWalkInContact() {
  return useQuery({
    queryKey: ['pos', 'walk-in'],
    queryFn: fetchWalkInContactId,
    staleTime: 5 * 60 * 1000,
  })
}

export function useContactSearch(q: string) {
  return useQuery({
    queryKey: ['pos', 'contact-search', q],
    queryFn: () => searchSellableContacts(q),
    enabled: q.trim().length >= 2,
  })
}

export function usePosCheckout() {
  return useMutation({
    mutationFn: (args: { contactId: string; lines: CheckoutLine[]; method: string; pay: boolean }) =>
      posCheckout(args),
  })
}
```

- [ ] **Step 3: Typecheck**

Run: `npm -w @tsk/web run typecheck`
Expected: keine Fehler.

- [ ] **Step 4: Commit**

```bash
git add apps/web/src/lib/posQueries.ts apps/web/src/hooks/usePos.ts
git commit -m "feat(pos): data layer — walk-in resolver, contact search, checkout hook"
```

---

## Task 5: `types.ts` + `BarcodeInput` + `ProductGrid`

**Files:**
- Create: `apps/web/src/screens/pos/types.ts`
- Create: `apps/web/src/screens/pos/BarcodeInput.tsx`
- Create: `apps/web/src/screens/pos/ProductGrid.tsx`

- [ ] **Step 1: `types.ts`**

Create `apps/web/src/screens/pos/types.ts`:

```ts
// Geteilter Warenkorb-Typ + Netto-Berechnung (Formel deckungsgleich mit
// order_recalc: qty * unit_price * (1 - discount_pct/100), geklemmt auf >= 0).
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
  return Math.max(0, l.qty * l.unitPrice * (1 - l.discountPct / 100))
}
```

- [ ] **Step 2: `BarcodeInput.tsx`**

Create `apps/web/src/screens/pos/BarcodeInput.tsx`:

```tsx
import { useState, type CSSProperties } from 'react'
import { useTranslation } from 'react-i18next'
import type { CatalogItem } from '@/lib/retailQueries'

const inputStyle: CSSProperties = {
  padding: '8px 10px', borderRadius: 8, border: '0.5px solid var(--hairline)',
  background: 'var(--surface-strong)', color: 'var(--ink)', font: 'inherit', fontSize: 13.5, width: '100%',
}

// USB-Scanner = Tastatur + Enter. Lookup gegen den geladenen Katalog (in-memory).
export function BarcodeInput({ catalog, onScan }: { catalog: CatalogItem[]; onScan: (item: CatalogItem) => void }) {
  const { t } = useTranslation()
  const [val, setVal] = useState('')
  const [err, setErr] = useState(false)

  function submit() {
    const code = val.trim()
    if (!code) return
    const hit = catalog.find((c) => c.barcode != null && c.barcode === code)
    if (hit) { onScan(hit); setVal(''); setErr(false) }
    else setErr(true)
  }

  return (
    <div>
      <input style={inputStyle} value={val} autoFocus
        placeholder={t('pos.scan_placeholder')}
        onChange={(e) => { setVal(e.target.value); setErr(false) }}
        onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); submit() } }} />
      {err && <div className="chip chip-red" style={{ marginTop: 4 }}>{t('pos.scan_unknown', { code: val })}</div>}
    </div>
  )
}
```

- [ ] **Step 3: `ProductGrid.tsx`**

Create `apps/web/src/screens/pos/ProductGrid.tsx`:

```tsx
import type { CSSProperties } from 'react'
import { useTranslation } from 'react-i18next'
import { Pill, chf } from '@/foundation'
import type { CatalogItem } from '@/lib/retailQueries'

const cardStyle: CSSProperties = {
  display: 'flex', flexDirection: 'column', gap: 4, padding: '10px 12px', minHeight: 92,
  borderRadius: 10, border: '0.5px solid var(--hairline)', background: 'var(--surface-strong)',
  color: 'var(--ink)', font: 'inherit', textAlign: 'left', cursor: 'pointer',
}

export function ProductGrid({ items, onAdd }: { items: CatalogItem[]; onAdd: (item: CatalogItem) => void }) {
  const { t } = useTranslation()
  if (items.length === 0) {
    return <div className="caption-2" style={{ padding: 'var(--space-3)' }}>{t('pos.no_products')}</div>
  }
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(150px, 1fr))', gap: 'var(--space-2)' }}>
      {items.map((it) => {
        const soldOut = it.on_hand <= 0 && !it.serialized
        return (
          <button key={it.variant_id} type="button" style={{ ...cardStyle, opacity: soldOut ? 0.5 : 1 }}
            disabled={soldOut} onClick={() => onAdd(it)}>
            <span style={{ fontWeight: 600, fontSize: 13.5 }}>{it.name}</span>
            <span className="caption-2">{it.sku ?? ''}</span>
            <span className="tabular-nums" style={{ marginTop: 'auto' }}>{chf(it.price)}</span>
            <span style={{ display: 'flex', gap: 4, alignItems: 'center' }}>
              <span className="caption-2 tabular-nums">{it.on_hand}</span>
              {it.low && <Pill tone="warning" size="sm">{t('shop.low')}</Pill>}
              {it.serialized && <Pill tone="info" size="sm">{t('shop.serialized')}</Pill>}
            </span>
          </button>
        )
      })}
    </div>
  )
}
```

- [ ] **Step 4: Typecheck + Commit**

Run: `npm -w @tsk/web run typecheck`
Expected: keine Fehler.
```bash
git add apps/web/src/screens/pos/types.ts apps/web/src/screens/pos/BarcodeInput.tsx apps/web/src/screens/pos/ProductGrid.tsx
git commit -m "feat(pos): cart types, barcode input, product grid"
```

---

## Task 6: `CustomerPicker`

**Files:**
- Create: `apps/web/src/screens/pos/CustomerPicker.tsx`

- [ ] **Step 1: Komponente schreiben**

Create `apps/web/src/screens/pos/CustomerPicker.tsx`:

```tsx
import { useState, type CSSProperties } from 'react'
import { useTranslation } from 'react-i18next'
import { Sheet } from '@/components/Sheet'
import { useContactSearch } from '@/hooks/usePos'

const inputStyle: CSSProperties = {
  padding: '8px 10px', borderRadius: 8, border: '0.5px solid var(--hairline)',
  background: 'var(--surface-strong)', color: 'var(--ink)', font: 'inherit', fontSize: 13.5, width: '100%',
}

// Zeigt den aktuellen Kunden als Chip; Klick öffnet die Suche. „Zurücksetzen"
// stellt Laufkundschaft wieder her (Handler liegt im PosScreen).
export function CustomerPicker({ name, isWalkIn, onPick, onReset }: {
  name: string
  isWalkIn: boolean
  onPick: (id: string, name: string) => void
  onReset: () => void
}) {
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)
  const [q, setQ] = useState('')
  const { data: results = [], isFetching } = useContactSearch(q)

  return (
    <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
      <span className="caption-2">{t('pos.customer')}:</span>
      <button type="button" className="chip" onClick={() => setOpen(true)}>{name}</button>
      {!isWalkIn && (
        <button type="button" className="btn-ghost btn" onClick={onReset}>{t('pos.walk_in_reset')}</button>
      )}
      <Sheet open={open} onClose={() => setOpen(false)} title={t('pos.pick_customer')} width={460}>
        <input style={inputStyle} autoFocus placeholder={t('pos.search_customer')}
          value={q} onChange={(e) => setQ(e.target.value)} />
        <div style={{ marginTop: 8, display: 'grid', gap: 2 }}>
          {isFetching && <div className="caption-2">{t('common.loading', 'Lädt …')}</div>}
          {!isFetching && q.trim().length >= 2 && results.length === 0 && (
            <div className="caption-2">{t('pos.no_customer_hits')}</div>
          )}
          {results.map((c) => (
            <button key={c.id} type="button" className="sb-row" style={{ width: '100%', textAlign: 'left' }}
              onClick={() => { onPick(c.id, c.name); setOpen(false); setQ('') }}>{c.name}</button>
          ))}
        </div>
      </Sheet>
    </div>
  )
}
```

- [ ] **Step 2: Typecheck + Commit**

Run: `npm -w @tsk/web run typecheck`
Expected: keine Fehler.
```bash
git add apps/web/src/screens/pos/CustomerPicker.tsx
git commit -m "feat(pos): customer picker with search + walk-in reset"
```

---

## Task 7: `CartPanel`

**Files:**
- Create: `apps/web/src/screens/pos/CartPanel.tsx`

- [ ] **Step 1: Komponente schreiben**

Create `apps/web/src/screens/pos/CartPanel.tsx`. Reine Präsentation; State + Handler liegen im `PosScreen`. `SerialSelect` spiegelt das Muster aus `CheckoutSheet`:

```tsx
import type { CSSProperties } from 'react'
import { useTranslation } from 'react-i18next'
import { chf } from '@/foundation'
import { useAvailableSerials } from '@/hooks/useRetail'
import { CustomerPicker } from '@/screens/pos/CustomerPicker'
import { type CartLine, lineNet } from '@/screens/pos/types'

const inputStyle: CSSProperties = {
  padding: '6px 8px', borderRadius: 8, border: '0.5px solid var(--hairline)',
  background: 'var(--surface-strong)', color: 'var(--ink)', font: 'inherit', fontSize: 13, width: '100%',
}
const METHODS = ['cash', 'card', 'twint', 'bank'] as const

function SerialSelect({ variantId, value, onChange }: { variantId: string; value: string | null; onChange: (v: string) => void }) {
  const { t } = useTranslation()
  const { data: serials = [] } = useAvailableSerials(variantId)
  return (
    <select style={inputStyle} value={value ?? ''} onChange={(e) => onChange(e.target.value)}>
      <option value="">{t('shop.pick_serial')}</option>
      {serials.map((s) => <option key={s.id} value={s.id}>{s.serial_no}</option>)}
    </select>
  )
}

export interface CartPanelProps {
  lines: CartLine[]
  customerName: string
  isWalkIn: boolean
  onPickCustomer: (id: string, name: string) => void
  onResetCustomer: () => void
  onQty: (variantId: string, qty: number) => void
  onDiscount: (variantId: string, pct: number) => void
  onSerial: (variantId: string, serialId: string) => void
  onRemove: (variantId: string) => void
  method: string
  onMethod: (m: string) => void
  payNow: boolean
  onPayNow: (b: boolean) => void
  onCheckout: () => void
  pending: boolean
  error: string | null
}

export function CartPanel(p: CartPanelProps) {
  const { t } = useTranslation()
  const subtotal = p.lines.reduce((s, l) => s + l.qty * l.unitPrice, 0)
  const discount = p.lines.reduce((s, l) => s + (l.qty * l.unitPrice - lineNet(l)), 0)
  const total = p.lines.reduce((s, l) => s + lineNet(l), 0)
  const missingSerial = p.lines.some((l) => l.serialized && !l.serialUnitId)
  const canCheckout = p.lines.length > 0 && !missingSerial && !p.pending

  return (
    <div style={{ display: 'grid', gap: 12, alignContent: 'start' }}>
      <CustomerPicker name={p.customerName} isWalkIn={p.isWalkIn} onPick={p.onPickCustomer} onReset={p.onResetCustomer} />

      {p.lines.length === 0 ? (
        <div className="caption-2" style={{ padding: 'var(--space-3)' }}>{t('pos.cart_empty')}</div>
      ) : (
        <div style={{ display: 'grid', gap: 8 }}>
          {p.lines.map((l) => (
            <div key={l.variantId} style={{ display: 'grid', gap: 6, padding: 8, border: '0.5px solid var(--hairline)', borderRadius: 8 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
                <span style={{ fontWeight: 600, fontSize: 13.5 }}>{l.name}</span>
                <button type="button" className="btn-ghost btn" aria-label={t('contacts.checkout.remove')} onClick={() => p.onRemove(l.variantId)}>×</button>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '64px 1fr 70px', gap: 8, alignItems: 'center' }}>
                <input style={inputStyle} type="number" min="1" step="1" aria-label={t('contacts.checkout.qty')}
                  value={l.qty} onChange={(e) => p.onQty(l.variantId, Number(e.target.value))} />
                <span className="tabular-nums caption-2">{chf(l.unitPrice)} × {l.qty}</span>
                <span className="tabular-nums" style={{ textAlign: 'right', fontWeight: 600 }}>{chf(lineNet(l))}</span>
              </div>
              <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                <span className="caption-2">{t('pos.discount')} %</span>
                <input style={{ ...inputStyle, maxWidth: 80 }} type="number" min="0" max="100" step="1"
                  value={l.discountPct} onChange={(e) => p.onDiscount(l.variantId, Number(e.target.value))} />
              </div>
              {l.serialized && (
                <SerialSelect variantId={l.variantId} value={l.serialUnitId} onChange={(v) => p.onSerial(l.variantId, v)} />
              )}
            </div>
          ))}
        </div>
      )}

      <div style={{ display: 'grid', gap: 4 }}>
        <Row label={t('pos.subtotal')} value={chf(subtotal)} />
        {discount > 0 && <Row label={t('pos.discount')} value={`− ${chf(discount)}`} />}
        <Row label={t('pos.total')} value={chf(total)} strong />
      </div>

      <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
        <label style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
          <input type="checkbox" checked={p.payNow} onChange={(e) => p.onPayNow(e.target.checked)} />
          {t('contacts.checkout.pay_now')}
        </label>
        <select style={{ ...inputStyle, maxWidth: 160 }} value={p.method} disabled={!p.payNow} onChange={(e) => p.onMethod(e.target.value)}>
          {METHODS.map((m) => <option key={m} value={m}>{t(`contacts.checkout.method_${m}`, { defaultValue: m })}</option>)}
        </select>
      </div>

      {missingSerial && <div className="chip chip-red">{t('pos.missing_serial')}</div>}
      {p.error && <div className="chip chip-red">{p.error}</div>}

      <button className="btn" style={{ padding: '12px' }} disabled={!canCheckout} onClick={p.onCheckout}>
        {p.pending ? t('common.saving') : t('pos.charge', { total: chf(total) })}
      </button>
    </div>
  )
}

function Row({ label, value, strong }: { label: string; value: string; strong?: boolean }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', fontWeight: strong ? 600 : 400 }}>
      <span>{label}</span><span className="tabular-nums">{value}</span>
    </div>
  )
}
```

- [ ] **Step 2: Typecheck + Commit**

Run: `npm -w @tsk/web run typecheck`
Expected: keine Fehler.
```bash
git add apps/web/src/screens/pos/CartPanel.tsx
git commit -m "feat(pos): cart panel — lines, discount, totals, payment"
```

---

## Task 8: `ReceiptView` + Druck-CSS + Rechnungsnummer-Query

**Files:**
- Modify: `apps/web/src/lib/posQueries.ts` (Rechnungsnummer-Helper)
- Create: `apps/web/src/screens/pos/ReceiptView.tsx`
- Create: `apps/web/src/styles/pos-print.css`

- [ ] **Step 1: Rechnungsnummer-Helper in `posQueries.ts` ergänzen**

Am Ende von `apps/web/src/lib/posQueries.ts` anhängen:

```ts
export async function fetchInvoiceNumber(invoiceId: string): Promise<string | null> {
  const { data, error } = await supabase.from('invoices').select('number').eq('id', invoiceId).maybeSingle()
  if (error) throw error
  return (data as { number: string | null } | null)?.number ?? null
}
```

- [ ] **Step 2: `pos-print.css`**

Create `apps/web/src/styles/pos-print.css`:

```css
@media print {
  body * { visibility: hidden; }
  .pos-receipt, .pos-receipt * { visibility: visible; }
  .pos-receipt { position: absolute; inset: 0; margin: 0; padding: 16px; width: 80mm; }
  .pos-receipt__noprint { display: none !important; }
}
```

- [ ] **Step 3: `ReceiptView.tsx`**

Create `apps/web/src/screens/pos/ReceiptView.tsx`:

```tsx
import { useTranslation } from 'react-i18next'
import { chf, dateMedium } from '@/foundation'
import { type CartLine, lineNet } from '@/screens/pos/types'
import '@/styles/pos-print.css'

export interface ReceiptData {
  invoiceNumber: string | null
  customerName: string
  lines: CartLine[]
  total: number
  method: string
  paid: boolean
  date: string
}

export function ReceiptView({ data, onClose }: { data: ReceiptData; onClose: () => void }) {
  const { t } = useTranslation()
  return (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.45)', display: 'flex',
      alignItems: 'center', justifyContent: 'center', zIndex: 50 }}>
      <div className="pos-receipt glass-thin" style={{ background: 'var(--surface)', color: 'var(--ink)',
        borderRadius: 12, padding: 20, width: 360, maxWidth: '90vw' }}>
        <div style={{ textAlign: 'center', fontWeight: 700, fontSize: 16 }}>Tauchsport Käge · TSK Zürich</div>
        <div className="caption-2" style={{ textAlign: 'center', marginBottom: 10 }}>
          {t('pos.receipt')} {data.invoiceNumber ?? ''} · {dateMedium(data.date)}
        </div>
        <div className="caption-2" style={{ marginBottom: 8 }}>{t('pos.customer')}: {data.customerName}</div>
        <div style={{ display: 'grid', gap: 4, borderTop: '0.5px solid var(--hairline)', paddingTop: 8 }}>
          {data.lines.map((l) => (
            <div key={l.variantId} style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
              <span>{l.qty}× {l.name}{l.discountPct > 0 ? ` (−${l.discountPct}%)` : ''}</span>
              <span className="tabular-nums">{chf(lineNet(l))}</span>
            </div>
          ))}
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', fontWeight: 700, marginTop: 8,
          borderTop: '0.5px solid var(--hairline)', paddingTop: 8 }}>
          <span>{t('pos.total')}</span><span className="tabular-nums">{chf(data.total)}</span>
        </div>
        <div className="caption-2" style={{ marginTop: 4 }}>
          {data.paid ? t(`contacts.checkout.method_${data.method}`, { defaultValue: data.method }) : t('pos.unpaid')}
        </div>
        <div className="pos-receipt__noprint" style={{ display: 'flex', gap: 8, marginTop: 16 }}>
          <button className="btn-secondary btn" style={{ flex: 1 }} onClick={onClose}>{t('common.close', 'Schließen')}</button>
          <button className="btn" style={{ flex: 1 }} onClick={() => window.print()}>{t('pos.print')}</button>
        </div>
      </div>
    </div>
  )
}
```

- [ ] **Step 4: Typecheck + Commit**

Run: `npm -w @tsk/web run typecheck`
Expected: keine Fehler. (Falls `dateMedium` nicht aus `@/foundation` exportiert ist, stattdessen `new Date(data.date).toLocaleDateString('de-CH')` verwenden.)
```bash
git add apps/web/src/lib/posQueries.ts apps/web/src/screens/pos/ReceiptView.tsx apps/web/src/styles/pos-print.css
git commit -m "feat(pos): printable receipt + print stylesheet"
```

---

## Task 9: `PosScreen` (Orchestrierung) + Route

**Files:**
- Create: `apps/web/src/screens/pos/PosScreen.tsx`
- Modify: `apps/web/src/App.tsx` (Lazy-Import + Route, neben `/shop`)

- [ ] **Step 1: `PosScreen.tsx`**

Create `apps/web/src/screens/pos/PosScreen.tsx`:

```tsx
import { useEffect, useMemo, useState, type CSSProperties } from 'react'
import { useTranslation } from 'react-i18next'
import { PageHeader, Loader } from '@/foundation'
import { useCatalog } from '@/hooks/useRetail'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { canEditOps } from '@/lib/auth'
import { useWalkInContact, usePosCheckout } from '@/hooks/usePos'
import { fetchInvoiceNumber } from '@/lib/posQueries'
import { BarcodeInput } from '@/screens/pos/BarcodeInput'
import { ProductGrid } from '@/screens/pos/ProductGrid'
import { CartPanel } from '@/screens/pos/CartPanel'
import { ReceiptView, type ReceiptData } from '@/screens/pos/ReceiptView'
import { type CartLine, lineNet } from '@/screens/pos/types'
import type { CatalogItem } from '@/lib/retailQueries'
import type { CheckoutLine } from '@/lib/financeQueries'

const inputStyle: CSSProperties = {
  padding: '8px 10px', borderRadius: 8, border: '0.5px solid var(--hairline)',
  background: 'var(--surface-strong)', color: 'var(--ink)', font: 'inherit', fontSize: 13.5, width: '100%',
}

export function PosScreen() {
  const { t } = useTranslation()
  const { data: user } = useCurrentUser()
  const { data: catalog = [], isLoading } = useCatalog()
  const { data: walkInId } = useWalkInContact()
  const checkout = usePosCheckout()

  const [q, setQ] = useState('')
  const [lines, setLines] = useState<CartLine[]>([])
  const [contactId, setContactId] = useState<string | null>(null)
  const [contactName, setContactName] = useState(t('pos.walk_in'))
  const [method, setMethod] = useState('cash')
  const [payNow, setPayNow] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [receipt, setReceipt] = useState<ReceiptData | null>(null)

  const isWalkIn = contactId == null || contactId === walkInId
  useEffect(() => {
    if (contactId == null && walkInId) { setContactId(walkInId); setContactName(t('pos.walk_in')) }
  }, [walkInId, contactId, t])

  const filtered = useMemo(() => {
    const s = q.trim().toLowerCase()
    if (!s) return catalog
    return catalog.filter((c) =>
      c.name.toLowerCase().includes(s) || (c.sku ?? '').toLowerCase().includes(s) || (c.brand ?? '').toLowerCase().includes(s))
  }, [catalog, q])

  function addToCart(item: CatalogItem) {
    setError(null)
    setLines((ls) => {
      const idx = ls.findIndex((l) => l.variantId === item.variant_id)
      if (idx >= 0) return ls.map((l, i) => (i === idx ? { ...l, qty: l.qty + 1 } : l))
      return [...ls, {
        variantId: item.variant_id, name: item.name, sku: item.sku,
        unitPrice: item.price, qty: 1, discountPct: 0,
        serialized: item.serialized, serialUnitId: null,
      }]
    })
  }
  const setQty = (id: string, qty: number) =>
    setLines((ls) => ls.map((l) => (l.variantId === id ? { ...l, qty: Math.max(1, qty || 1) } : l)))
  const setDiscount = (id: string, pct: number) =>
    setLines((ls) => ls.map((l) => (l.variantId === id ? { ...l, discountPct: Math.min(100, Math.max(0, pct || 0)) } : l)))
  const setSerial = (id: string, sid: string) =>
    setLines((ls) => ls.map((l) => (l.variantId === id ? { ...l, serialUnitId: sid || null } : l)))
  const removeLine = (id: string) => setLines((ls) => ls.filter((l) => l.variantId !== id))

  function pickCustomer(id: string, name: string) { setContactId(id); setContactName(name) }
  function resetCustomer() { setContactId(walkInId ?? null); setContactName(t('pos.walk_in')) }

  async function onCheckout() {
    if (!contactId) { setError(t('pos.no_walk_in')); return }
    setError(null)
    const total = lines.reduce((s, l) => s + lineNet(l), 0)
    const payload: CheckoutLine[] = lines.map((l) => ({
      description: l.sku ? `${l.name} · ${l.sku}` : l.name,
      quantity: l.qty, unit_price: l.unitPrice, discount_pct: l.discountPct,
      tax_rate_id: null, item_type: 'product', item_ref_id: l.variantId,
      serial_unit_id: l.serialized ? l.serialUnitId : null,
    }))
    try {
      const res = await checkout.mutateAsync({ contactId, lines: payload, method, pay: payNow })
      let number: string | null = null
      try { number = await fetchInvoiceNumber(res.invoice_id) } catch { /* Beleg ohne Nummer */ }
      setReceipt({ invoiceNumber: number, customerName: contactName, lines, total, method, paid: payNow, date: new Date().toISOString() })
      setLines([]); resetCustomer()
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t('common.error'))
    }
  }

  if (!user || !canEditOps(user.role)) {
    return <div style={{ padding: 'var(--space-4)' }}>{t('pos.not_allowed')}</div>
  }
  if (isLoading) return <div style={{ padding: 'var(--space-4)' }}><Loader /></div>

  return (
    <div className="screen" style={{ padding: 'var(--space-4)', display: 'grid', gap: 'var(--space-3)' }}>
      <PageHeader title={t('pos.title')} subtitle={t('pos.subtitle')} />
      <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0,1.4fr) minmax(300px,1fr)', gap: 'var(--space-4)', alignItems: 'start' }}>
        <div style={{ display: 'grid', gap: 'var(--space-3)' }}>
          <BarcodeInput catalog={catalog} onScan={addToCart} />
          <input style={inputStyle} placeholder={t('pos.search')} value={q} onChange={(e) => setQ(e.target.value)} />
          <ProductGrid items={filtered} onAdd={addToCart} />
        </div>
        <CartPanel
          lines={lines} customerName={contactName} isWalkIn={isWalkIn}
          onPickCustomer={pickCustomer} onResetCustomer={resetCustomer}
          onQty={setQty} onDiscount={setDiscount} onSerial={setSerial} onRemove={removeLine}
          method={method} onMethod={setMethod} payNow={payNow} onPayNow={setPayNow}
          onCheckout={onCheckout} pending={checkout.isPending} error={error}
        />
      </div>
      {receipt && <ReceiptView data={receipt} onClose={() => setReceipt(null)} />}
    </div>
  )
}
```

- [ ] **Step 2: Route in `App.tsx`**

Bei den anderen Lazy-Screen-Imports (neben `ProductsScreen`) ergänzen:
```tsx
const PosScreen = lazy(() => import('@/screens/pos/PosScreen').then((m) => ({ default: m.PosScreen })))
```
Und direkt neben der bestehenden `/shop`-Route (gleicher Pfad-Stil — relativ `kasse` bzw. absolut `/kasse` wie der `/shop`-Nachbar) einfügen:
```tsx
<Route path="/kasse" element={<PosScreen />} />
```

- [ ] **Step 3: Typecheck + Commit**

Run: `npm -w @tsk/web run typecheck`
Expected: keine Fehler.
```bash
git add apps/web/src/screens/pos/PosScreen.tsx apps/web/src/App.tsx
git commit -m "feat(pos): PosScreen orchestration + /kasse route"
```

---

## Task 10: Sidebar-Eintrag + „Heute"-Button + i18n

**Files:**
- Modify: `apps/web/src/components/Sidebar.tsx:49` (ITEMS)
- Modify: `apps/web/src/screens/TodayScreen.tsx:148-159` (DispatcherToday actions)
- Modify: `apps/web/src/i18n/locales/de.json`, `apps/web/src/i18n/locales/en.json`

- [ ] **Step 1: Sidebar-ITEM**

In `apps/web/src/components/Sidebar.tsx`, im `ITEMS`-Array direkt nach der `/shop`-Zeile einfügen:
```tsx
  { to: '/kasse',             icon: 'wallet',   i18nKey: 'pos',             roles: ['dispatcher', 'owner', 'cd'] },
```

- [ ] **Step 2: „Heute"-Button (DispatcherToday)**

In `apps/web/src/screens/TodayScreen.tsx`, in `DispatcherToday` als **erstes** Element des `actions`-Fragments einfügen (vor `WhatsAppButton`):
```tsx
            <button type="button" className="btn" onClick={() => navigate('/kasse')}>
              {t('pos.open_till')}
            </button>
```
(`navigate` und `t` sind in `DispatcherToday` bereits vorhanden.)

- [ ] **Step 3: i18n — `de.json`**

In `apps/web/src/i18n/locales/de.json` unter `nav` den Schlüssel ergänzen:
```json
    "pos": "Kasse",
```
und einen neuen Top-Level-Block `pos` hinzufügen:
```json
  "pos": {
    "title": "Kasse",
    "subtitle": "Theken-Verkauf",
    "open_till": "Kasse öffnen",
    "search": "Produkt suchen …",
    "scan_placeholder": "Barcode scannen …",
    "scan_unknown": "Unbekannter Barcode: {{code}}",
    "no_products": "Keine Produkte",
    "customer": "Kunde",
    "walk_in": "Laufkundschaft",
    "walk_in_reset": "Zurücksetzen",
    "pick_customer": "Kunde wählen",
    "search_customer": "Name suchen …",
    "no_customer_hits": "Keine Treffer",
    "cart_empty": "Warenkorb leer",
    "discount": "Rabatt",
    "subtotal": "Zwischensumme",
    "total": "Total",
    "charge": "Kassieren · {{total}}",
    "missing_serial": "Seriennummer für serialisierte Artikel wählen",
    "receipt": "Beleg",
    "print": "Drucken",
    "unpaid": "Offen (nicht bezahlt)",
    "not_allowed": "Kein Zugriff auf die Kasse",
    "no_walk_in": "Laufkundschaft-Kontakt fehlt — Seed-Migration anwenden"
  },
```

- [ ] **Step 4: i18n — `en.json`**

In `apps/web/src/i18n/locales/en.json` unter `nav`:
```json
    "pos": "Till",
```
und Top-Level-Block:
```json
  "pos": {
    "title": "Till",
    "subtitle": "Counter sale",
    "open_till": "Open till",
    "search": "Search product …",
    "scan_placeholder": "Scan barcode …",
    "scan_unknown": "Unknown barcode: {{code}}",
    "no_products": "No products",
    "customer": "Customer",
    "walk_in": "Walk-in",
    "walk_in_reset": "Reset",
    "pick_customer": "Pick customer",
    "search_customer": "Search name …",
    "no_customer_hits": "No matches",
    "cart_empty": "Cart empty",
    "discount": "Discount",
    "subtotal": "Subtotal",
    "total": "Total",
    "charge": "Charge · {{total}}",
    "missing_serial": "Select a serial for serialized items",
    "receipt": "Receipt",
    "print": "Print",
    "unpaid": "Open (unpaid)",
    "not_allowed": "No access to the till",
    "no_walk_in": "Walk-in contact missing — apply the seed migration"
  },
```

- [ ] **Step 5: Typecheck + JSON-Validität + Commit**

Run: `npm -w @tsk/web run typecheck`
Run: `python3 -c "import json; json.load(open('apps/web/src/i18n/locales/de.json')); json.load(open('apps/web/src/i18n/locales/en.json')); print('JSON OK')"`
Expected: keine Fehler, `JSON OK`.
```bash
git add apps/web/src/components/Sidebar.tsx apps/web/src/screens/TodayScreen.tsx apps/web/src/i18n/locales/de.json apps/web/src/i18n/locales/en.json
git commit -m "feat(pos): sidebar entry, Today till button, i18n"
```

---

## Task 11: Schlussverifikation

**Files:** keine (nur Verifikation)

- [ ] **Step 1: Backend grün**

Run: `supabase db reset && supabase test db`
Expected: `Result: PASS`, inkl. `12_pos_walk_in_discount.sql` (4/4). Alle übrigen Suiten bleiben grün.

- [ ] **Step 2: Frontend typrein**

Run: `npm -w @tsk/web run typecheck`
Expected: keine Fehler.

- [ ] **Step 3: Manueller Klicktest (Dev-Server gegen lokale Supabase)**

Run: `npm -w @tsk/web run dev`
Checkliste:
- `/heute` zeigt als Dispatcher den „Kasse öffnen"-Button → führt nach `/kasse`. Sidebar zeigt „Kasse".
- Produkt anlegen (`/shop`) inkl. Barcode + Bestand, dann an der Kasse: Tap auf Karte legt in den Warenkorb; erneuter Tap erhöht die Menge.
- Barcode ins Scan-Feld tippen + Enter → Artikel landet im Warenkorb; unbekannter Code → Fehlermeldung.
- Zeilen-Rabatt 25 % → Zeilensumme und Total sinken korrekt.
- Kunde wählen (Suche) und auf Laufkundschaft zurücksetzen.
- „Kassieren" → Beleg erscheint, „Drucken" öffnet den Druckdialog nur mit dem Beleg; Warenkorb ist danach leer.
- Bestand des verkauften Artikels ist in `/shop` gesunken.

- [ ] **Step 4: Abschluss-Commit (falls offen) + Branch-Hinweis**

```bash
git status   # sollte sauber sein
```
Edge-Deploy/Prod sind nicht Teil dieses Plans (kein neues RPC, kein Edge-Change) — nur `supabase db push` für die Seed-Migration beim nächsten Prod-Rollout.

---

## Spec-Coverage (Self-Review)

| Spec-Anforderung | Task |
|---|---|
| Dedizierte Kasse `/kasse`, rollen-gegated | 9, 10 |
| Produkt-Grid + Tap-to-Cart | 5, 9 |
| Kundenauswahl + Laufkundschaft-Default | 2, 4, 6, 9 |
| Barcode-Scan | 3, 5, 9 |
| Rabatte erfasst (`order_lines.discount_pct`) | 1 (vorhanden), 7 (UI) |
| Druckbarer Beleg | 8 |
| Einstieg „Heute" + Sidebar | 10 |
| Tests (Rabatt-Pfad + Seed) | 1, 11 |

Nicht aus der Spec, aber bewusst weggelassen: per-Zeile **Steuer** (Atoll heute CHF-only ohne MwSt → `tax_rate_id: null`); `discount_chf` (YAGNI, %-Rabatt genügt). Beides additiv nachrüstbar.

---

## Execution Handoff

Plan vollständig und gespeichert unter `docs/superpowers/plans/2026-06-05-theken-pos.md`.

