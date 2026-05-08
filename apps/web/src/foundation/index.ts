/**
 * ATOLL Foundation — public API.
 *
 * Components, lib functions and providers re-exported under stable paths.
 * Import from `@/foundation` rather than reaching into subfolders.
 */

// ─────────── Atoms ───────────
export { Avatar, type AvatarProps, type AvatarSize } from './components/Avatar'
export { AvatarStack, type AvatarStackProps, type AvatarStackPerson } from './components/AvatarStack'
export { Pill, type PillProps, type PillTone, type PillSize } from './components/Pill'
export { SearchInput, type SearchInputProps, type SearchInputSize } from './components/SearchInput'

// ─────────── Molecules ───────────
export { KpiCard, type KpiCardProps, type KpiVariant } from './components/KpiCard'
export { KpiGrid, type KpiGridProps } from './components/KpiGrid'
export { FilterTabBar, type FilterTabBarProps, type FilterTab } from './components/FilterTabBar'
export { SortDropdown, type SortDropdownProps, type SortOption } from './components/SortDropdown'
export { ChecklistItem, type ChecklistItemProps, type ChecklistState } from './components/ChecklistItem'
export { TouchpointCard, type TouchpointCardProps, type TouchpointChannel, type TouchpointDirection } from './components/TouchpointCard'
export { CourseRow, type CourseRowProps } from './components/CourseRow'
export { PromptCard, type PromptCardProps, type PromptTone } from './components/PromptCard'
export { EmptyState, type EmptyStateProps } from './components/EmptyState'
export { Banner, type BannerProps, type BannerTone } from './components/Banner'
export { ToastProvider, useToast, type ToastInput, type ToastTone } from './components/Toast'

// ─────────── Layouts ───────────
export { AppShell, type AppShellProps } from './layouts/AppShell'
export { Sidebar, SidebarNavItem, type SidebarNavItemProps } from './layouts/Sidebar'
export { PageHeader, type PageHeaderProps } from './layouts/PageHeader'
export { MasterDetail, ListPane, DetailPane, type ListPaneProps, type DetailPaneProps } from './layouts/MasterDetail'
export { Tabs, type TabsProps, type TabDefinition } from './layouts/Tabs'
export { Drawer, type DrawerProps, type DrawerSide } from './layouts/Drawer'

// ─────────── Compounds ───────────
export { BrevetsView, type BrevetsViewProps } from './compounds/BrevetsView'

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
export { avatarColor, courseTypeColor, proTierColor, AVATAR_PALETTE } from './lib/colors'
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
