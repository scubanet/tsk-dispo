/**
 * ATOLL Foundation — public API.
 *
 * Components, lib functions and providers re-exported under stable paths.
 * Import from `@/foundation` rather than reaching into subfolders.
 */

// ─────────── Components ───────────
export { Avatar, type AvatarProps, type AvatarSize } from './components/Avatar'
export { AvatarStack, type AvatarStackProps, type AvatarStackPerson } from './components/AvatarStack'
export { Pill, type PillProps, type PillTone, type PillSize } from './components/Pill'
export { SearchInput, type SearchInputProps, type SearchInputSize } from './components/SearchInput'

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
