/**
 * ATOLL Foundation — public API.
 *
 * Import from `@/foundation` rather than reaching into subfolders.
 *
 * Layout (GL-004 Phase 5a):
 *   - `primitives/` — pure UI atoms + molecules with no domain knowledge
 *     (Avatar, Pill, Banner, KpiCard, EmptyState, …). Reusable in any app.
 *   - `patterns/`   — domain compositions (CourseRow, TouchpointCard,
 *     BrevetsView, ContactHeader, inline-field family). Aware of ATOLL
 *     domain concepts.
 *   - `layouts/`    — page/shell scaffolding (AppShell, Sidebar, Drawer,
 *     PageHeader, MasterDetail, Tabs).
 *
 * The split is conceptual: primitives evolve with the design language,
 * patterns evolve with the product.
 */

// ─────────── Primitives — atoms ───────────
export { Avatar, type AvatarProps, type AvatarSize } from './primitives/Avatar'
export { AvatarStack, type AvatarStackProps, type AvatarStackPerson } from './primitives/AvatarStack'
export { Pill, type PillProps, type PillTone, type PillSize } from './primitives/Pill'
export { SearchInput, type SearchInputProps, type SearchInputSize } from './primitives/SearchInput'

// ─────────── Primitives — molecules ───────────
export { KpiCard, type KpiCardProps, type KpiVariant } from './primitives/KpiCard'
export { KpiGrid, type KpiGridProps } from './primitives/KpiGrid'
export { FilterTabBar, type FilterTabBarProps, type FilterTab } from './primitives/FilterTabBar'
export { SortDropdown, type SortDropdownProps, type SortOption } from './primitives/SortDropdown'
export { ChecklistItem, type ChecklistItemProps, type ChecklistState } from './primitives/ChecklistItem'
export { PromptCard, type PromptCardProps, type PromptTone } from './primitives/PromptCard'
export { EmptyState, type EmptyStateProps } from './primitives/EmptyState'
export { Banner, type BannerProps, type BannerTone } from './primitives/Banner'
export { ToastProvider, useToast, type ToastInput, type ToastTone } from './primitives/Toast'
export { Loader, type LoaderProps } from './primitives/Loader'

// ─────────── Layouts ───────────
export { AppShell, type AppShellProps } from './layouts/AppShell'
export { Sidebar, SidebarNavItem, type SidebarNavItemProps } from './layouts/Sidebar'
export { PageHeader, type PageHeaderProps } from './layouts/PageHeader'
export { MasterDetail, ListPane, DetailPane, type ListPaneProps, type DetailPaneProps } from './layouts/MasterDetail'
export { Tabs, type TabsProps, type TabDefinition } from './layouts/Tabs'
export { Drawer, type DrawerProps, type DrawerSide } from './layouts/Drawer'

// ─────────── Patterns — domain compositions ───────────
export { CourseRow, type CourseRowProps } from './patterns/CourseRow'
export { TouchpointCard, type TouchpointCardProps, type TouchpointChannel, type TouchpointDirection } from './patterns/TouchpointCard'
export { BrevetsView, type BrevetsViewProps } from './patterns/BrevetsView'

// ─────────── Providers ───────────
export { ThemeProvider, useTheme, type ThemeProviderProps } from './providers/ThemeProvider'

// ─────────── Lib ───────────
export {
  isActive,
  activeOnly,
  deriveDiverTier,
  deriveProTier,
  displayTier,
  compareProTier,
  compareDiverTier,
} from './lib/tier'
export { canTeach } from './lib/teaching-rules'
export {
  calculateCompensation,
  payeeRateFromProTier,
  DEFAULT_RATES,
  type CompensationInput,
} from './lib/compensation'
export { avatarColor, courseTypeColor, proTierColor, padiLevelColor, AVATAR_PALETTE } from './lib/colors'
export {
  dateShort,
  dateMedium,
  dateLong,
  weekday,
  weekdayLong,
  timeShort,
  dateTimeShort,
  relativeTime,
  relativeDay,
  isToday,
  isTomorrow,
  isYesterday,
  todayISO,
  toISODate,
} from './lib/dates'
export { chf, chfPlain, int, decimal, percent, initialsFromName } from './lib/numbers'
export { Icon, type IconName, type IconProps } from './lib/icons'
