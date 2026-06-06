import { supabase } from '@/lib/supabase'

// Phase-2 / M2 Retail — Lesefunktionen + Mutationen.
// Postgres numeric kommt als String → Number() casten.

type Num = number | string | null | undefined
const n = (v: Num): number => Number(v ?? 0)

// ── Katalog (Variante + Produkt + Bestand) ───────────────────────────────────
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

export async function fetchCatalog(): Promise<CatalogItem[]> {
  const [varsRes, ohRes] = await Promise.all([
    supabase.from('product_variants')
      .select('id, sku, barcode, price, currency, products!inner(id, name, brand, model, category_id, reorder_point, serialized)')
      .eq('is_active', true),
    supabase.from('v_inventory_on_hand').select('variant_id, on_hand'),
  ])
  if (varsRes.error) throw varsRes.error
  if (ohRes.error) throw ohRes.error

  const oh = new Map<string, number>()
  for (const r of (ohRes.data ?? []) as Array<{ variant_id: string; on_hand: Num }>) {
    oh.set(r.variant_id, n(r.on_hand))
  }

  return ((varsRes.data ?? []) as unknown as CatalogVariantRow[]).map((v) => {
    const p = v.products
    const on_hand = oh.get(v.id) ?? 0
    const reorder = n(p?.reorder_point)
    return {
      variant_id: v.id,
      product_id: p?.id ?? '',
      name: p?.name ?? '—',
      brand: p?.brand ?? null,
      model: p?.model ?? null,
      sku: v.sku,
      barcode: v.barcode,
      price: n(v.price),
      currency: v.currency,
      on_hand,
      reorder_point: reorder,
      low: reorder > 0 && on_hand <= reorder,
      serialized: Boolean(p?.serialized),
      category_id: p?.category_id ?? null,
    }
  })
}

export interface SerialOption { id: string; serial_no: string }
export async function fetchAvailableSerials(variantId: string): Promise<SerialOption[]> {
  const { data, error } = await supabase.from('serial_units')
    .select('id, serial_no').eq('variant_id', variantId).eq('status', 'in_stock').order('serial_no')
  if (error) throw error
  return (data ?? []) as SerialOption[]
}

export interface ProductCategory { id: string; code: string; name: string }
export async function fetchCategories(): Promise<ProductCategory[]> {
  const { data, error } = await supabase.from('product_categories')
    .select('id, code, name').eq('is_active', true).order('name')
  if (error) throw error
  return (data ?? []) as ProductCategory[]
}

// Mandant des eingeloggten Users (für tenant_id bei Inserts; RLS verlangt Gleichheit).
export async function fetchCurrentTenantId(): Promise<string | null> {
  const { data, error } = await supabase.rpc('current_tenant_id')
  if (error) throw error
  return (data as string | null) ?? null
}

// ── Mutationen ────────────────────────────────────────────────────────────────
export interface ProductInput {
  productId?: string
  variantId?: string
  tenantId: string
  name: string
  categoryId?: string | null
  brand?: string | null
  model?: string | null
  serialized: boolean
  sku?: string | null
  price: number
  cost: number
  reorderPoint: number
}

export async function saveProduct(input: ProductInput): Promise<{ productId: string; variantId: string }> {
  if (input.productId && input.variantId) {
    const { error: pe } = await supabase.from('products').update({
      name: input.name,
      category_id: input.categoryId ?? null,
      brand: input.brand ?? null,
      model: input.model ?? null,
      serialized: input.serialized,
      reorder_point: input.reorderPoint,
    }).eq('id', input.productId)
    if (pe) throw pe
    const { error: ve } = await supabase.from('product_variants').update({
      sku: input.sku ?? null,
      price: input.price,
      cost: input.cost,
    }).eq('id', input.variantId)
    if (ve) throw ve
    return { productId: input.productId, variantId: input.variantId }
  }

  const { data: prod, error: pe } = await supabase.from('products').insert({
    tenant_id: input.tenantId,
    name: input.name,
    category_id: input.categoryId ?? null,
    brand: input.brand ?? null,
    model: input.model ?? null,
    serialized: input.serialized,
    reorder_point: input.reorderPoint,
  }).select('id').single()
  if (pe) throw pe
  const productId = (prod as { id: string }).id

  const { data: variant, error: ve } = await supabase.from('product_variants').insert({
    tenant_id: input.tenantId,
    product_id: productId,
    sku: input.sku ?? null,
    price: input.price,
    cost: input.cost,
  }).select('id').single()
  if (ve) throw ve

  return { productId, variantId: (variant as { id: string }).id }
}

export async function adjustStock(variantId: string, qty: number, reason = 'adjustment'): Promise<void> {
  const { error } = await supabase.rpc('inventory_adjust', {
    p_variant_id: variantId,
    p_qty: qty,
    p_reason: reason,
  })
  if (error) throw error
}
