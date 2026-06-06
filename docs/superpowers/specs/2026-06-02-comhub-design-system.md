# ComHub Design System — Implementation Spec

> Reference for reimplementing the **CoHub** web prototype natively in SwiftUI (macOS / iOS).
> Source: `/tmp/cohub-handoff/cohub/project/`. All numbers below are read directly from the prototype's CSS variables and JSX inline styles — no invention. The app is named **CoHub** in the prototype ("CoHub Konto", title "CoHub"); the native target is **ComHub** — names below quote the prototype.

Brand: macOS/iOS "Apple HIG" look. Floating rounded window with traffic lights, translucent (vibrancy) sidebar, blue accent, multi-pane list/detail layouts, SF-symbol-style stroke icons. Seven modules: **Heute, Kalender, Kombox, Kontakte, Aufgaben, CardInbox, Einstellungen**. German UI strings.

---

## 1. Design Tokens

Base font stack (`--font`): `-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Helvetica Neue", Helvetica, Arial, sans-serif`. In SwiftUI use the system font (`.font(.system(...))`, default San Francisco). `-webkit-font-smoothing: antialiased` → SwiftUI default.

### 1.1 Color tokens (light + dark)

Express as **Asset Catalog colorsets** with Any/Dark appearance variants (preferred — gives free `Color("…")` semantic names that auto-switch), or as a `Color` extension computed off `@Environment(\.colorScheme)`. All values are sRGB. Many tokens are black/white with alpha → in SwiftUI use `Color.primary/.secondary` opacity or explicit `Color(white:0/1, opacity:)`.

| CSS var | Light | Dark | Proposed SwiftUI name | Notes |
|---|---|---|---|---|
| `--accent` | `#007AFF` | `#0A84FF` | `Color.accent` (or `.tint`) | System blue. Use `.tint(.accent)`; could also map to `Color.accentColor`. |
| `--accent-soft` | `rgba(0,122,255,0.12)` | `rgba(10,132,255,0.22)` | `Color.accentSoft` | Tinted button/avatar-action backgrounds. |
| `--accent-fg` / `--text-on-accent` | `#ffffff` | `#ffffff` | `Color.onAccent` | Always white. |
| `--win-bg` | `#ffffff` | `#1c1c1e` | `Color.windowBg` | Window body. |
| `--content-bg` | `#ffffff` | `#1c1c1e` | `Color.contentBg` | Main content pane + cards. |
| `--panel-bg` | `#f6f6f8` | `#232325` | `Color.panelBg` | Secondary list rails (Kombox rail, Aufgaben rail, contacts section headers). |
| `--sidebar-bg` | `rgba(244,246,250,0.72)` | `rgba(40,40,44,0.62)` | `Color.sidebarBg` | Translucent nav sidebar (blur behind). |
| `--toolbar-bg` | `rgba(255,255,255,0.72)` | `rgba(34,34,37,0.72)` | `Color.toolbarBg` | Titlebar; blur behind. |
| `--text-1` | `rgba(0,0,0,0.86)` | `rgba(255,255,255,0.92)` | `Color.text1` | Primary text. |
| `--text-2` | `rgba(0,0,0,0.52)` | `rgba(255,255,255,0.55)` | `Color.text2` | Secondary. |
| `--text-3` | `rgba(0,0,0,0.34)` | `rgba(255,255,255,0.36)` | `Color.text3` | Tertiary / captions / placeholder. |
| `--sep` | `rgba(0,0,0,0.08)` | `rgba(255,255,255,0.09)` | `Color.sep` | Hairline separators (1px → use `Divider` or 1pt overlay). |
| `--sep-strong` | `rgba(0,0,0,0.14)` | `rgba(255,255,255,0.16)` | `Color.sepStrong` | Stronger borders (ghost buttons, checkbox rings, scrollbar). |
| `--hover` | `rgba(0,0,0,0.045)` | `rgba(255,255,255,0.06)` | `Color.hover` | Hover bg (macOS pointer hover; rarely on iOS). |
| `--sel` | `rgba(0,0,0,0.075)` | `rgba(255,255,255,0.10)` | `Color.selection` | Non-accent selected row (sidebar "klar" style). |
| `--field-bg` | `rgba(0,0,0,0.045)` | `rgba(255,255,255,0.07)` | `Color.fieldBg` | Search fields, segmented track, empty-state icon tile, composer. |
| `--chip-bg` | `rgba(0,0,0,0.06)` | `rgba(255,255,255,0.10)` | `Color.chipBg` | Grey chips, count badges. |
| `--traffic-border` | `rgba(0,0,0,0.08)` | `rgba(255,255,255,0.12)` | `Color.trafficBorder` | 0.5px ring on traffic-light dots. |

### 1.2 Shadows

| CSS var | Light | Dark | SwiftUI |
|---|---|---|---|
| `--card-shadow` | `0 1px 2px rgba(0,0,0,0.06), 0 4px 14px rgba(0,0,0,0.05)` | `0 1px 2px rgba(0,0,0,0.3), 0 6px 18px rgba(0,0,0,0.32)` | Two stacked `.shadow()` modifiers, or one approximated `.shadow(color:.black.opacity(0.06/0.3), radius: 7, y: 4)`. Used on Heute cards/widgets + Segmented active thumb. |
| `--win-shadow` | `0 0 0 0.5px rgba(0,0,0,0.18), 0 30px 70px -12px rgba(20,30,50,0.45)` | `0 0 0 0.5px rgba(0,0,0,0.6), 0 30px 70px -12px rgba(0,0,0,0.6)` | Floating-window drop shadow + 0.5px hairline border. On native macOS the OS window provides this; only needed if drawing a faux-window. |

### 1.3 Radii

| CSS var | Value | SwiftUI `cornerRadius` |
|---|---|---|
| `--r-win` | `11px` | 11 (window) |
| `--r-card` | `12px` | 12 (settings groups, card list detail box, contact detail). NOTE: Heute uses **16** literal for cards, not the token. |
| `--r-ctl` | `7px` | 7 (ToolBtn, ghost "Heute" button, settings icon tiles) |
| `--r-pill` | `999px` | use `Capsule()` |

Other literal radii seen in JSX: `8` (sidebar rows, AccentBtn, SegmentedControl, SearchField, badge pill `9`), `6` (Chip, small swatches), `14`/`16`/`20` (cards, bubbles, composer), `50%` (avatars/dots → `Circle()`).

### 1.4 Density tokens

Switched by a `density` setting (compact / regular / comfy). Implement as an environment value or a `Density` struct injected via `@Environment`. Default = **regular**.

| Token | compact | regular | comfy | Meaning / SwiftUI |
|---|---|---|---|---|
| `--fs` (base body) | 12px | 13px | 14px | Base font size. |
| `--row-h` (list row height) | 26px | 30px | 38px | Generic list row min height. |
| `--pad` (section padding) | 11px | 14px | 20px | Section padding. |
| `--gap` | 7px | 10px | 14px | Inter-element gap. |

NOTE: in practice the views mostly hardcode their own font sizes/paddings (e.g. `fontSize:13.5`, `padding:"10px 14px"`); density vars are defined but only `ViewKalender` receives a `density` prop (and doesn't visibly branch on it). Treat density as a **global scale hook** to wire later, not as something each view fully respects in the prototype.

### 1.5 Avatar color palette `window.AV`

```
AV = ["#FF6482","#5E9CFF","#FFB340","#34C759","#BF5AF2","#FF8E5E","#64D2FF","#FF453A","#AC8E68","#30D158"]
```

### 1.6 Channel / calendar / nav palettes

`CHANNELS` (Kombox): `mail #1F8FFF` (icon `mail`), `imessage #34C759` (icon `message`), `whatsapp #25D366` (icon `message`).
`CALS` (Kalender sources): `schule #007AFF`, `menu #FF9F0A`, `privat #34C759`, `arbeit #BF5AF2`, `feiertag #FF453A`.
`TASK_LISTS`: Schule `#007AFF`, Privat `#34C759`, Arbeit `#BF5AF2`.
Nav accent colors (per module icon): Heute `#FF9F0A`, Kalender `#FF453A`, Kombox `#34C759`, Kontakte `#8E8E93`, Aufgaben `#FF9F0A`, CardInbox `#BF5AF2`, Einstellungen `#8E8E93`.

### 1.7 Desktop wallpaper (out of scope on native)

`--desktop` light: `radial-gradient(120% 100% at 30% 0%, #aebfd6 0%, #8ea3c4 35%, #6f87ad 65%, #4f6488 100%)`; dark: `radial-gradient(120% 100% at 30% 0%, #2a3550 0%, #1d2740 38%, #141b2e 70%, #0c1020 100%)`. Plus a diagonal shimmer overlay. Only relevant if rendering a faux desktop behind a faux window — native apps fill the real OS window.

---

## 2. Shared Components (`shared.jsx`)

### 2.1 Avatar
Circular gradient avatar with initials.
- **Props**: `name`, `size` (default 34), `color` (optional override), `ring` (bool).
- **Color**: `color || hashColor(name)`. Background = `linear-gradient(150deg, c, shade(c,-18))` (top-left `c` → bottom-right darker). Foreground white, `fontWeight:600`, `fontSize: size*0.4`, `letterSpacing:0.2`.
- **Shadow**: if `ring` → `0 0 0 2px var(--content-bg), 0 1px 3px rgba(0,0,0,.2)` (outer ring matching bg + drop). Else inner top highlight `inset 0 1px 0 rgba(255,255,255,.25)`.
- **Initials algorithm** (`initials(name)`): strip all non-letter/non-space chars (`/[^\p{L}\s]/gu`), trim, split on whitespace. If no parts → `"?"`. If one part → first 2 chars uppercased. Else → first char of first part + first char of last part, uppercased.
- **Hash color** (`hashColor(str, palette=AV)`): `h=0; for each char: h = (h*31 + charCode) >>> 0;` then `palette[h % palette.length]`. (Unsigned 32-bit rolling hash.)
- **`shade(hex, amt)`**: parse hex → r,g,b; add `amt` to each channel; clamp 0–255; reformat hex. Negative `amt` darkens. Used for avatar gradients (-18), biz-card gradients (-30), Heute card-inbox swatch (-30).
- **SwiftUI**: `Circle().fill(LinearGradient(...))` with `Text(initials)`. Port `hashColor`/`initials`/`shade` as Swift helpers. Group avatars pass `color:"#8E8E93"` (grey) explicitly.

### 2.2 Chip
Small rounded label, grey or colored-dot variant.
- Layout: `inline-flex`, `gap:5`, **height 18**, `padding:0 7px`, **borderRadius 6**, `fontSize:11`, `fontWeight:500`, `lineHeight:1`.
- **Grey variant** (no `color`): bg `--chip-bg`, text `--text-2`, no border.
- **Colored variant** (`color` set): bg transparent, text = `color`, border `1px solid {color}55` (the color at 33% alpha), plus a leading **6×6 dot** (`borderRadius:50%`, bg `color`).
- Usage: Heute "Menü: …" (`#FF9F0A`), Heute "als Nächstes" (`--accent`), CardInbox "{n} neu" (`--accent`).
- **SwiftUI**: `HStack(spacing:5){ optional dot; Text }`.padding(.horizontal,7).frame(height:18).background(Capsule-ish `RoundedRectangle(cornerRadius:6)`).

### 2.3 Segmented (Tag / Woche / Monat)
- Container: `inline-flex`, `padding:2`, `gap:2`, height **28** (md) or **24** (sm), `borderRadius:8`, bg `--field-bg`.
- Each button: `padding:0 12px`, `borderRadius:6`, `fontSize:12.5`, `fontWeight: active?600:500`.
  - Active: text `--text-1`, bg `--content-bg`, shadow `0 1px 2px rgba(0,0,0,.18), 0 0 0 .5px rgba(0,0,0,.04)`.
  - Inactive: text `--text-2`, transparent bg.
- `transition: all .12s ease`.
- **SwiftUI**: a custom segmented control (native `Picker(.segmented)` is close but styling differs — prefer a custom `HStack` of buttons with a sliding/static white thumb).

### 2.4 ToolBtn (toolbar icon button)
- Square, `size` default **30**, `borderRadius:7`. Icon centered.
- bg: `active || hover ? --hover : transparent`. Icon color `--text-2`, default icon size **17**. `transition: background .12s`.
- Accepts `children` to override the icon. Used in titlebar, Kombox/Kalender/Aufgaben headers.
- **SwiftUI**: `Button` with `.frame(width:30,height:30)`, `RoundedRectangle(7)` hover/pressed fill, icon `Image(systemName:)` `.font(.system(size:17))`.

### 2.5 AccentBtn (pill action button)
- Height **28**, `padding:0 13px`, `borderRadius:8`, `fontSize:12.5`, `fontWeight:600`. `inline-flex`, icon+label `gap:6`.
- **Filled** (default): bg `--accent`, text `--text-on-accent` (white), shadow `0 1px 2px rgba(0,0,0,.15)`, no border.
- **Ghost** (`ghost`): bg transparent, text `--text-1`, border `1px solid --sep-strong`, no shadow.
- Usage: Kalender "+ Termin" (filled), CardInbox "Zu Kontakten" (filled) + "Mail senden" (ghost), Einstellungen "Profil bearbeiten"/"Teilen" (ghost).
- **SwiftUI**: `Button` styled; two style variants (filled/ghost).

### 2.6 SearchField
- Layout: `flex`, `gap:7`, height **30**, `width` default 220 (Kombox/Kontakte pass `"100%"`), `padding:0 10px`, `borderRadius:8`, bg `--field-bg`.
- Leading `search` icon size **14**, color `--text-3`. Text input `fontSize:13`, color `--text-1`, transparent. Placeholder default `"Suchen"`.
- **SwiftUI**: `HStack{ Image(systemName:"magnifyingglass"); TextField }`.

### 2.7 EmptyState
- Vertically + horizontally centered column, `gap:10`, color `--text-3`, `padding:40`.
- Icon tile: **60×60**, `borderRadius:16`, bg `--field-bg`, centered icon size **30** (`stroke:1.4`) color `--text-3`.
- Title: `fontSize:16`, `fontWeight:600`, color `--text-2`.
- Sub (optional): `fontSize:13`, `maxWidth:280`.
- **SwiftUI**: `VStack` centered; used by Kombox (no selection), Kontakte (no selection), Aufgaben (no tasks).

### 2.8 HeaderBar (content toolbar row)
- Height **52**, `flexShrink:0`, `flex` row, `align:center`, `gap:10`, `padding:0 16px`, bottom border `1px solid --sep`.
- Children laid out left→right with `flex:1` spacers to push items. Used by Kalender, Kombox reader, Aufgaben.
- **SwiftUI**: an `HStack`.frame(height:52).padding(.horizontal,16) with a `Divider` at the bottom; spacers via `Spacer()`.

---

## 3. Shell (`app.jsx`)

### 3.1 Window
- Faux window: `width: min(1180px, 94vw)`, `height: min(780px, 92vh)`, `borderRadius: --r-win (11)`, `overflow:hidden`, bg `--win-bg`, shadow `--win-shadow`. Column layout: titlebar over body. **On native macOS** this is the real `Window`; reproduce only the internal chrome.

### 3.2 Titlebar (height 44)
- Height **44**, bottom border `1px solid --sep`, bg `--toolbar-bg` with `blur(30px)` (use macOS title bar material / `.ultraThinMaterial`).
- Left cluster (`padding:0 16px 0 18px`, `gap:14`): **TrafficLights** then a **ToolBtn** `icon:"sidebar"` that toggles sidebar collapse.
- **TrafficLights**: three 12×12 dots, `gap:8`, each `borderRadius:50%`, `border:0.5px solid --traffic-border`. Colors red `#ff5f57`, yellow `#febc2e`, green `#28c840`. (On native macOS use the real traffic lights.)
- Center: title **"CoHub"** (`fontSize:14`, `fontWeight:700`, `letterSpacing:-0.1`, color `--text-1`). Followed by `flex:1` spacer.
- Right (`padding:0 16px`, `gap:6`, color `--text-3`): sun/moon icon (size 15) reflecting theme + caption "Tweaks oben rechts ⚙︎" (`fontSize:11.5`). Native: drop the tweaks hint; theme follows system.

### 3.3 Body
Row: **Sidebar** + content pane (`flex:1`, column, bg `--content-bg`). Content routes by `route` (persisted in localStorage `cohub_route`, default `"heute"`).

### 3.4 Sidebar (`Sidebar`)
- Width **230** (collapses to 0 with `width .22s cubic-bezier(.4,0,.2,1)`; collapse toggled from titlebar).
- Background depends on sidebar style setting: `schlicht` → solid `--panel-bg`, no blur; otherwise (`klar`/`akzent`) → `--sidebar-bg` with `backdrop-filter: blur(40px) saturate(180%)` (use vibrancy material). Right border `1px solid --sep`.
- Top spacer height 14. Then the nav list `gap:2`.

**Nav model** (`NAV`, order matters): `heute` (house, `#FF9F0A`), `kalender` (calendar, `#FF453A`), `kombox` (bubbles, `#34C759`), `kontakte` (people, `#8E8E93`), `aufgaben` (checklist, `#FF9F0A`), `cardinbox` (cardinbox, `#BF5AF2`) — then a **separator** — then `einstellungen` (gear, `#8E8E93`).
- Separator: `height:1`, bg `--sep`, `margin:8px 18px`.

**SidebarItem row**:
- `flex` row, `gap:10`, height **32**, `padding:0 10px`, `margin:0 8px`, `borderRadius:8`, width `calc(100% - 16px)`.
- Background by state: selected+`akzent` style → `--accent`; else selected → `--sel`; else hover → `--hover`; else transparent.
- Icon size **17**, `stroke:1.9`, color = its nav color (white if accent-selected).
- Label: `flex:1`, `fontSize:13.5`, `fontWeight: active?600:500`, color `--text-1` (white if accent-selected).
- **Count badge** (when `badge>0`): `fontSize:11`, `fontWeight:600`, `minWidth:18`, `height:18`, `padding:0 5px`, `borderRadius:9` (pill). bg `--chip-bg` (or `rgba(255,255,255,.28)` if accent-selected); text `--text-2` (white if accent-selected).
- **Badge sources** (computed live): `kombox` = count of `THREADS` with `unread`; `cardinbox` = count of `CARDS` with `status==="new"`; `aufgaben` = count of `TASKS` with `due==="Heute" && !done`. (Einstellungen has no badge.)

**User footer** (bottom of sidebar, `padding:10px 18px`, `gap:9`): **Avatar** `name:"Lukas Vogt"` size **28**; then a column — name `fontSize:12.5`/`fontWeight:600`/`--text-1`/nowrap, subtitle "CoHub Konto" `fontSize:10.5`/`--text-3`. A `flex:1` spacer separates the nav list from this footer.

### 3.5 Sidebar style variants (setting `sidebarStyle`: klar / akzent / schlicht)
- **klar** (default-ish, prototype default is "klar"): translucent bg, selected row uses `--sel` (grey).
- **akzent**: translucent bg, selected row uses `--accent` (blue fill, white text/icon/badge).
- **schlicht**: solid `--panel-bg`, no blur; selection still grey (`--sel`).
(Prototype `TWEAK_DEFAULTS` = theme light, density regular, sidebarStyle "klar".)

---

## 4. Per-Module Layouts

General data shapes the views bind to:
- **EVENTS**: `{ d:dayIndex(0–6), s/e:"HH:MM", title, sub?, loc?, cal:CALSkey, allDay? }`. `EARLY_NOTES`: `{ d, time, title, cal }`.
- **CONTACTS** via `C(first,last,accts[],email,extra{})`: `{ first, last, name, accts:["apple"/"atoll"], email, org?, role?, phone? }`. `ACCOUNTS = {apple:"Apple", atoll:"Atoll"}`.
- **THREADS**: `{ id, channel:"mail"/"imessage"/"whatsapp", name, org?, subject?(mail), time, unread, flagged?, preview, attach?, group?, msgs:[{from:"me"/"them", who?, time, text}] }`.
- **TASKS**: `{ id, list:"l1"/"l2"/"l3", title, note?, due?("Heute"/"Morgen"/…), flagged?, done, prio(0/1/2) }`. `TASK_LISTS`: l1 Schule, l2 Privat, l3 Arbeit.
- **CARDS**: `{ id, name, role, org, email, phone, web, color, received, via, status:"new"/"saved" }`.

---

### 4.1 Heute (`view-heute.jsx`) — Dashboard (single scroll column)
Scroll container; inner `maxWidth:1080`, centered, `padding:30px 34px 40px`.

**Greeting block** (`marginBottom:8`):
- Date eyebrow: `fontSize:13`, `fontWeight:600`, color `--accent`, UPPERCASE, `letterSpacing:0.5` — "Dienstag, 2. Juni 2026".
- Big greeting: `fontSize:30`, `fontWeight:800`, `--text-1`, `letterSpacing:-0.4`, `marginTop:3` — "{Guten Morgen/Tag/Abend}, {name}." (greeting by hour: <11 Morgen, <17 Tag, else Abend; prototype hour fixed 9).
- Summary line: `fontSize:15`, `--text-2`, `marginTop:4` — "Du hast **N Termine**, **N Aufgaben** und **N ungelesene** Nachrichten heute." (bold spans `--text-1`).

**Two-column grid** (`marginTop:22`, `gap:18`, `gridTemplateColumns:"1.5fr 1fr"`, `alignItems:start`):

**Left — Agenda card** (bg `--content-bg`, border `1px --sep`, `borderRadius:16`, shadow `--card-shadow`):
- Header button (`padding:15px 18px 12px`, `gap:9`): calendar icon size 18 `#007AFF`; title "Heutiger Tagesablauf" (`fontSize:15`/`700`/`--text-1`, `flex:1`); trailing menu Chip "Menü: {title}" colored `#FF9F0A` (if a `menu` allDay event exists today). Tapping navigates to Kalender.
- Agenda rows (today's non-allDay events, sorted by start; `padding:0 18px 18px`): each row `flex`, `gap:14`, `padding:10px 0`, top border `1px --sep` (except first), `align:center`:
  - Time block width **46**, right-aligned: start `fontSize:13.5`/`700` (`--text-1` if it's the "next" event else `--text-2`); end `fontSize:11`/`--text-3`.
  - Color bar: width **4**, `borderRadius:3`, `minHeight:34`, bg = `CALS[cal].color`, stretches full row height.
  - Body (`flex:1`): title `fontSize:14`/`600`/`--text-1`, optional `· {sub}` (`fontWeight:500`/`--text-3`). If `loc`: row `fontSize:12`/`--text-3` with `pin` icon (11) + location.
  - "next" event also gets a trailing Chip "als Nächstes" colored `--accent`. ("next" = first event whose start ≥ now (09:24), else first event.)

**Right — three stacked Widgets** (`gap:18`). **Widget** = card (bg `--content-bg`, border `1px --sep`, `borderRadius:16`, shadow `--card-shadow`): header button (`padding:13px 16px 10px`, `gap:9`): tinted icon (17), title (`fontSize:14`/`700`/`flex:1`), optional `count` (`fontSize:12`/`600`/`--text-3`), trailing `chevR` (15, `--text-3`). Body `padding:0 16px 14px`.
- **Aufgaben heute** (icon checklist `#FF9F0A`, count): up to 4 today-open tasks, each row `gap:9`/`padding:6px 0`: empty 16×16 circle ring (`border:1.8px solid --sep-strong`), title (`fontSize:13`/`--text-1`/`flex:1`), trailing `flag` (12, `#FF9F0A` filled) if flagged. Empty → "Keine Aufgaben fällig 🎉" (`fontSize:12.5`/`--text-3`).
- **Kombox** (icon bubbles `#34C759`, count=unread): up to 3 unread threads, each `gap:10`/`padding:7px 0`: Avatar size 30 (grey if group), name (`fontSize:13`/`600`, ellipsis), subline `subject||preview` (`fontSize:12`/`--text-3`, ellipsis), trailing channel name (`fontSize:11`/`600`, colored by `CHANNELS[channel].color`).
- **CardInbox** (icon cardinbox `#BF5AF2`, count=new): up to 3 new cards, each `gap:10`/`padding:6px 0`: 34×22 gradient swatch (`borderRadius:5`, `linear-gradient(135deg, color, shade(color,-30))`), name (`fontSize:13`/`600`), org (`fontSize:11.5`/`--text-3`), trailing `received` (`fontSize:11`/`--text-3`).

**SwiftUI**: `ScrollView` → `VStack`. Two-column grid via `HStack(alignment:.top)` with proportional widths (1.5:1) or `Grid`. Cards = rounded-rect containers; rows = `HStack`s.

---

### 4.2 Kalender (`view-kalender.jsx`) — Tag / Woche / Monat
Column: HeaderBar, then either MonthView or (day-headers + AllDayRow + scrollable time grid).

**HeaderBar**: Segmented [Tag / Woche / Monat] (left) · spacer · centered title (`fontSize:16`/`700`, e.g. "Juni 2026" or "Dienstag, 2. Juni 2026") · spacer · nav cluster (`gap:2`): ToolBtn `chevL`, a ghost **"Heute"** button (height 28, `padding:0 12px`, `borderRadius:7`, border `1px --sep-strong`, `fontSize:12.5`/`600`), ToolBtn `chevR` · AccentBtn "+ Termin" (plus icon 15).

**Time-grid constants**: `HOUR_START=7`, `HOUR_END=18`, `PX_MIN=0.92` (px per minute → 60min = 55.2px). `NOW_MIN = 09:24`. Week base = Mon 01.06.2026; `TODAY_INDEX=1` (Di 02.06).

**Day headers row** (below HeaderBar, bottom border `1px --sep`, `paddingRight:11` to clear scrollbar): leading 54px gutter spacer, then per visible day a cell (`flex:1`, right border `1px --sep`, `padding:7px 10px`, baseline-aligned, `gap:7`): weekday label `Mo`… (`fontSize:12`/`600`, `--text-2`; today → `#FF453A`); big date number (`fontSize:18`/`700`; today → white on `#FF453A` rounded `borderRadius:8`, `padding:3px 7px`); month suffix `.MM` (`fontSize:11`/`--text-3`).

**AllDayRow** (only if any allDay event or early note in visible days; `minHeight:30`, bottom border `1px --sep`): 54px "ganztägig" label (`fontSize:10`/`--text-3`, right-aligned) + per-day column (`flex:1`, right border, `padding:4px 5px`, `gap:3`): each allDay event as a solid pill (`fontSize:11`/`600`, white text, bg=`CALS[cal].color`, `borderRadius:5`, `padding:2px 7px`, ellipsis); each early note as a row (`fontSize:10.5`/`--text-2`) with `clock` icon (11) + "{time} {title}".

**Time grid** (scrollable, `padding:6px 0`):
- **TimeGutter** width **54**: hour labels `07:00`…`18:00` absolutely positioned at `(h-7)*60*0.92 - 6`, right-aligned (`right:8`), `fontSize:10.5`/`500`/`--text-3`.
- **DayColumn** (`flex:1`, right border `1px --sep`): GridLines (horizontal `1px --sep` at each hour). EventBlocks absolutely positioned. **Now-line** for today: red `#FF453A`, a 8×8 dot at left + a 1.5px horizontal line at `top=(NOW_MIN-420)*0.92`.
- **EventBlock**: `top=(startMin-420)*0.92`, `height=max((end-start)*0.92, 16)-2`. Horizontal packing: overlapping events split into columns; `left = (100/cols)*col% + 1px`, `width = (100/cols)% - 3px`. Style: bg `cal.color+"22"` (~13% alpha), `borderLeft:3px solid cal.color`, `borderRadius:6`, `padding:3px 6px`, inset ring `inset 0 0 0 .5px {cal.color}33`. Title `fontSize:11.5`/`600`/`--text-1`, ellipsis. If `height>30`: subline `fontSize:10.5`/`--text-2` = start + (`· loc` or `· sub`).

**Column packing algorithm** (`packDay`): sort timed events by start; build clusters of mutually overlapping events (new cluster when `start ≥ clusterEnd`); within a cluster, greedily assign each event to the first column whose last end ≤ its start, else a new column; every event in the cluster gets `_cols = cluster column count`.

**Tag mode**: single visible day = `daySel`. **Woche**: days 0–6. **Monat**: `MonthView`.

**MonthView** (June 2026 grid, `padding:0 16px 16px`): weekday header row Mo–So (`fontSize:11`/`600`/`--text-3`, left-aligned). Grid `repeat(7,1fr)`, `gridAutoRows:1fr`, outer border `1px --sep` + `borderRadius:10`, cells have right+bottom `1px --sep`, `padding:6`, `minHeight:72`. Empty leading/trailing cells get bg `--field-bg`. Day number in a 22×22 circle (`fontSize:12.5`; today(=2) → `700` white on `#FF453A`, else `--text-1`). Below: up to 4 event-source **dots** (6×6, colored by distinct `CALS` of that day) — demo maps days 1–7 onto event day-indices 0–6. Click a day → switch to Tag mode for that day.

**SwiftUI**: header = HStack. Time grid = `ScrollView` with a `ZStack`/`Canvas` or absolute-positioned overlays (`GeometryReader` + `.offset`) for event blocks; gridlines via `Path`/overlay. Month = `LazyVGrid(columns: 7)`.

---

### 4.3 Kombox (`view-kombox.jsx`) — 3-pane unified inbox
Row: channel rail (180) · thread list (320) · reader (flex).

**Channel rail** (width **180**, right border `1px --sep`, `padding:14px 10px`, `gap:2`, bg `--panel-bg`):
- Section label "POSTEINGANG" (`fontSize:11`/`700`/`--text-3`, `padding:4px 10px 8px`).
- FILTERS: Alle (bubbles), Mail, iMessage, WhatsApp, Markiert (flag). Each row: `flex`/`gap:9`/height **32**/`padding:0 10px`/`borderRadius:7`; active → bg `--accent`, white text; else transparent, `--text-1`. Leading: for all/flagged an Icon (16); for channel filters a **ChannelDot** (16). Label `flex:1` `fontSize:13`/`fontWeight:active?600:500`. Trailing count badge (same pill style as sidebar: `minWidth:18`/`height:18`/`borderRadius:9`; bg `rgba(255,255,255,.25)` if active else `--chip-bg`). Counts: Alle = total unread; Markiert = total flagged; channel = unread in that channel.
- **ChannelDot**: `size` square; `borderRadius: mail?4:50%` (mail = rounded square, chats = circle); bg = channel color; centered white channel icon (`size*0.66`, `stroke:2`); inset top highlight `inset 0 1px 0 rgba(255,255,255,.3)`.

**Thread list** (width **320**, right border `1px --sep`, column):
- List header (`padding:12px 14px 10px`, bottom border, `gap:10`): title = current filter label (`fontSize:17`/`700`) + ToolBtn `plus` on the right; then full-width SearchField "Suchen".
- **ThreadRow** (`flex`/`gap:10`/`padding:10px 14px`, bottom border `1px --sep`; active → bg `--accent`):
  - Unread+inactive: small `accent` dot 7×7 absolutely at `left:5`, vertically centered.
  - Avatar 38 (grey if group), with a channel badge overlaid bottom-right (`right:-3, bottom:-3`, padded `1.5` ring in `--content-bg` or `--accent` if active) containing a ChannelDot size 15.
  - Body: top line — name (`fontSize:13.5`, `fontWeight:unread?700:600`, white if active, ellipsis, `flex:1`) + time (`fontSize:11`, `--text-3` or `rgba(255,255,255,.8)` active). Optional subject line (mail) `fontSize:12.5`/`500`. Preview line `fontSize:12`/`--text-2` (white-ish if active), ellipsis; trailing `attach` icon (13) if attachment, `flag` icon (12, `#FF9F0A` filled, white if active) if flagged.
- Empty → centered "Keine Nachrichten" (`padding:40`/`--text-3`/`fontSize:13`).

**Reader** (`flex:1`, column). If a thread selected:
- **HeaderBar**: Avatar 30 (grey if group); column with name (`fontSize:14`/`600`) and a subline = ChannelDot(11)+channel name (`fontSize:11`/`--text-3`). Trailing actions depend on channel: **mail** → ToolBtns `reply, archive, flag, trash`; **chat** → `phone, video, ellipsis`.
- **MailReader** (`padding:22px 30px`): subject (`fontSize:21`/`700`, `lineHeight:1.25`); sender row (`margin:16 0 18`, bottom border, `gap:11`): Avatar 40, name + `· org` (`fontSize:13.5`/`600`; org `--text-3`/`500`), "an mich · {time}" (`fontSize:12`/`--text-3`), trailing ChannelDot mail size 22. Body paragraphs `fontSize:14`/`lineHeight:1.6`/`--text-1`, preserve newlines. If `attach`: an attachment chip (`marginTop:22`, `inline-flex`, `gap:10`, `padding:10px 14px`, border `1px --sep-strong`, `borderRadius:10`): 34×34 tile (`borderRadius:7`, bg `#FF453A22`) with red `attach` icon (17); filename "Rechnung_Mai_2026.pdf" (`fontSize:12.5`/`600`) + "284 KB · PDF" (`fontSize:11`/`--text-3`).
- **ChatReader** (`padding:20px 24px`, `gap:10`, column): centered meta line "{channel} · {Gruppe|Direktnachricht}" (`fontSize:11`/`--text-3`). Then **Bubble**s.
- **Bubble**: aligned right if `from==="me"` else left. Optional sender name `who` (group, not me) above (`fontSize:10.5`/`--text-3`/`marginLeft:10`). Bubble: `maxWidth:74%`, `padding:8px 12px`, `borderRadius:16`, `fontSize:13.5`/`lineHeight:1.42`, preserve newlines; **me** → bg `--accent` (or `#34C759` for WhatsApp), white text, tail = `borderBottomRightRadius:5`; **them** → bg `--field-bg`, `--text-1`, tail = `borderBottomLeftRadius:5`. Timestamp below (`fontSize:10`/`--text-3`/`margin:0 6px`).
- **Composer** (bottom, `flexShrink:0`, `padding:12px 18px`, top border `1px --sep`): a pill (`padding:7px 8px 7px 16px`, `borderRadius:20`, bg `--field-bg`) with text input (placeholder "Antworten…" for mail, "Nachricht via {channel}…" for chat; `fontSize:13.5`) and a 30×30 round send button (bg `--accent`, or `#34C759` WhatsApp) with white `paperplane` icon (16).
- If no thread: EmptyState (bubbles, "Keine Nachricht ausgewählt", "Wähle links eine Unterhaltung aus.").

**SwiftUI**: `NavigationSplitView` (three columns) or nested `HStack`s. On iOS collapse to push-navigation. Bubbles = asymmetric rounded rectangles.

---

### 4.4 Kontakte (`view-kontakte.jsx`) — 2-pane list + detail
Row: list (330) · detail (flex).

**List pane** (width **330**, right border `1px --sep`):
- Header (`padding:12px 14px 10px`, bottom border, `gap:10`): "Kontakte" (`fontSize:17`/`700`) + count (`fontSize:12`/`--text-3`) on the right; full-width SearchField "Kontakte suchen".
- Sorted by last name (or first) via `localeCompare(…, "de")`; grouped by first letter of `(last||first)`.
- **Section header** per letter: sticky top, `padding:3px 14px`, `fontSize:11`/`700`/`--text-3`, bg `--panel-bg`, bottom border `1px --sep`.
- **ContactRow** (`flex`/`gap:11`/`padding:7px 14px`, bottom border; active → bg `--accent`): Avatar 32; name = "{first} **{last}**" (first `600`, last `700`; white if active, `fontSize:13.5`, ellipsis); subline (`gap:6`, `marginTop:2`): account chips (per `accts` — `fontSize:10.5`/`500`, `padding:1px 6px`, `borderRadius:5`, bg `--chip-bg` or `rgba(255,255,255,.22)` active) + email (`fontSize:11.5`/`--text-3`, ellipsis).

**Detail pane** (`flex:1`, scroll). If none selected → EmptyState (people, "Kein Kontakt ausgewählt", "Wähle links einen Kontakt aus.").
- Hero (centered column, `padding:36px 30px 22px`, bottom border): Avatar **92**; name (`fontSize:24`/`700`, `marginTop:16`); optional "{role} · {org}" (`fontSize:14`/`--text-2`, `marginTop:3`).
- **Action buttons** row (`gap:10`, `marginTop:20`): Nachricht (message), Anruf (phone), Video (video), Mail (mail). Each = 42×42 circle bg `--accent-soft` with accent icon (19) + label below (`fontSize:11`/`--accent`).
- **DetailRows** (`padding:6px 30px 30px`, `maxWidth:520`): each row (skipped if no value) is a stacked label/value (`padding:9px 0`, bottom border `1px --sep`): label `fontSize:11`/`--text-3`/`500`; value `fontSize:13.5` (`--accent`/`500` if `accent` flag, else `--text-1`). Rows: E-Mail(accent), Telefon(accent), Firma, Funktion, Accounts (comma-joined account names).

**SwiftUI**: `NavigationSplitView` or `HStack`. List = `List`/`ScrollView` with section headers (`Section`/pinned headers). Detail = `ScrollView` `VStack`.

---

### 4.5 Aufgaben (`view-aufgaben.jsx`) — filter rail + task list
Row: lists rail (210) · tasks (flex).

**Lists rail** (width **210**, right border `1px --sep`, `padding:14px 10px`, bg `--panel-bg`, scroll):
- **Smart cards grid** (`grid 1fr 1fr`, `gap:8`, `marginBottom:14`): Alle (checklist, `--text-2`), Heute (clock, `#FF9F0A`), Markiert (flag, `#FF453A`). Each card: `textAlign:left`, `padding:9px 10px`, `borderRadius:10`; active → bg `--accent`, else bg `--field-bg`. Top: icon (16, white if active else its color). Below (`marginTop:6`, space-between baseline): label (`fontSize:11.5`/`600`/`--text-2` or white) + big count (`fontSize:16`/`700`/`--text-1` or white). Counts: Alle = open tasks; Heute = open due-today; Markiert = open flagged. (3 cards in a 2-col grid → third wraps to its own row.)
- Section "MEINE LISTEN" (`fontSize:11`/`700`/`--text-3`, `padding:0 8px 6px`).
- **List rows** (per TASK_LISTS): `flex`/`gap:9`/height **32**/`padding:0 10px`/`borderRadius:7`; active → bg `--accent`. Leading 11×11 color dot (white if active else list color); name (`flex:1`, `fontSize:13`/`fontWeight:active?600:500`); trailing open-count (`fontSize:12`/`--text-3` or `rgba(255,255,255,.8)`).

**Tasks pane** (`flex:1`, column):
- **HeaderBar**: 11×11 dot in current accent (= selected list color, or `#FF9F0A` Heute / `#FF453A` Markiert / `--accent` Alle) + title (`fontSize:20`/`700`) + spacer + ToolBtn `plus`.
- List (`padding:6px 26px 30px`, `maxWidth:680`): open tasks first; if any done → a "{n} erledigt" header (`fontSize:12`/`600`/`--text-3`, `padding:16px 0 4px`) then done tasks. Empty → EmptyState (checklist, "Keine Aufgaben", "Alles erledigt 🎉").
- **Task Row** (`flex`/`gap:11`/`padding:9px 4px`, bottom border, `align:flex-start`):
  - **TaskCheck**: 20×20 circle; done → filled with list color + white `check` (13, `stroke:2.4`); not done → `border:1.8px solid --sep-strong`, transparent.
  - Body: title row (`gap:7`) — title `fontSize:13.5` (`--text-1`; done → `--text-3` + strikethrough); if flagged & not done → `flag` (12, `#FF9F0A` filled); if `prio===2` & not done → red "!!" (`fontSize:13`/`700`/`#FF453A`). Optional note `fontSize:12`/`--text-3`/`marginTop:1`. Meta row (`gap:8`/`marginTop:3`): due (`fontSize:11`/`500`; `#FF9F0A` if "Heute" else `--text-3`); when viewing Alle/Heute/Markiert, also show list dot (7×7) + list name (`fontSize:11`/`--text-3`).

**SwiftUI**: rail = `VStack` with a `LazyVGrid(2 cols)` of cards + list rows. Tasks = `ScrollView` `VStack`. Checkbox = `Button` toggling done.

---

### 4.6 CardInbox (`view-cardinbox.jsx`) — list + gradient hero detail
Row: card list (340) · detail (flex, centered).

**List pane** (width **340**, right border `1px --sep`):
- Header (`padding:12px 14px 12px`, bottom border): "CardInbox" (`fontSize:17`/`700`) + Chip "{newCount} neu" (accent) on the right; subtitle "Eingehende digitale Visitenkarten" (`fontSize:12`/`--text-3`, `marginTop:3`).
- **CardListItem** (`flex`/`gap:12`/`padding:11px 14px`, bottom border; active → bg `--accent`): leading 46×30 gradient swatch (`borderRadius:6`, `linear-gradient(135deg, color, shade(color,-30))`, inset top highlight). Body: top line — name (`fontSize:13.5`/`600`, white if active, `flex:1`, ellipsis) + if `status==="new"` a 7×7 accent dot (white if active). "{role} · {org}" (`fontSize:12`/`--text-2`, ellipsis). "{via} · {received}" (`fontSize:11`/`--text-3`, `marginTop:1`).

**Detail pane** (`flex:1`, scroll, centered column, `padding:34px 30px`): inner `maxWidth:380`.
- **BizCard** (hero): `borderRadius:14`, `aspectRatio: 1.7/1`, `padding:20px 22px`, white text, bg `linear-gradient(135deg, color, shade(color,-30))`, shadow `0 8px 22px -8px {color}99, inset 0 1px 0 rgba(255,255,255,.25)`. Decorative translucent circles: one 110×110 at `right:-20,top:-20` (`rgba(255,255,255,.12)`), one 80×80 at `right:24,bottom:-30` (`rgba(255,255,255,.08)`). Content column: name (`fontSize:20`/`700`/`letterSpacing:0.2`), role (`fontSize:13`/`opacity:.92`/`marginTop:2`), spacer, footer row (space-between): org (`fontSize:14`/`600`/`opacity:.95`) + `qr` icon (22, `rgba(255,255,255,.85)`, `stroke:1.6`). (A `mini` variant exists with smaller sizes — not used in detail.)
- **Action row** (`margin:22px 0 6px`, `gap:10`): AccentBtn "Zu Kontakten" (people icon 15, filled) + AccentBtn ghost "Mail senden" (mail icon 15) + spacer + ToolBtn `trash`.
- **Field box** (`marginTop:14`, border `1px --sep`, `borderRadius:12`, clipped): stacked rows (`padding:10px 14px`, bottom border except last): label (`fontSize:11`/`--text-3`) over value (`fontSize:13.5`; accent for the first three). Rows: E-Mail(accent), Telefon(accent), Website(accent), Firma, "Empfangen via" = "{via} · {received}".

**SwiftUI**: list = `ScrollView` of rows. BizCard = `ZStack` with `LinearGradient` background + decorative `Circle()`s clipped to a `RoundedRectangle(14)` with fixed aspect ratio.

---

### 4.7 Einstellungen (`view-einstellungen.jsx`) — single settings column
Scroll; inner `maxWidth:620`, centered, `padding:26px 30px 40px`.

- **Profile header** (`gap:16`, `marginBottom:26`): Avatar **64** + column [name "Lukas Vogt" `fontSize:21`/`700`; "lukas@cohub.app · CoHub Konto" `fontSize:13`/`--text-3`] + spacer + AccentBtn ghost "Profil bearbeiten".
- **Group** = labeled card. Group label `fontSize:11.5`/`700`/`--text-3`, UPPERCASE, `letterSpacing:0.4`, `padding:0 4px 7px`. Card: bg `--content-bg`, border `1px --sep`, `borderRadius:12`, clipped. `marginBottom:24`.
- **SettingRow** (`flex`/`gap:12`/`padding:11px 16px`, bottom border except `last`): optional 28×28 icon tile (`borderRadius:7`, bg = given color, white icon 16); title (`fontSize:13.5`/`500`) + optional sub (`fontSize:11.5`/`--text-3`); trailing `right` element.
- Groups & rows:
  - **Verbundene Konten**: Apple (people, `#1F8FFF`, "iCloud Kontakte & Kalender", StatusDot on); Atoll (people, `#FF8E5E`, "Studio-Adressbuch", StatusDot on, last).
  - **Kombox-Kanäle**: Mail (mail, `#1F8FFF`, "3 Postfächer · IMAP", on); iMessage (message, `#34C759`, "lukas@cohub.app", on); WhatsApp (message, `#25D366`, "+41 79 204 88 31", on, last).
  - **CardInbox**: "Meine digitale Visitenkarte" (qr, `#BF5AF2`, "cohub.app/c/lukas", trailing AccentBtn ghost "Teilen"); "Automatisch zu Kontakten" (inboxdown, `#5E9CFF`, "Neue Karten als Entwurf speichern", trailing **Toggle** on, last).
  - **Darstellung**: "Erscheinungsbild, Dichte & Sidebar" (sun, `#FF9F0A`, "Über das Tweaks-Panel oben rechts anpassbar", trailing `chevR` 15, last). On native, point this at real Settings, not the tweaks panel.
- Footer: "CoHub 1.0 · Prototyp" (`fontSize:11.5`/`--text-3`, centered, `marginTop:10`).
- **StatusDot**: dot 8×8 (`#34C759` if on else `--text-3`) + "Verbunden"/"Getrennt" (`fontSize:12`/`--text-2`).
- **Toggle**: 40×24 pill (`borderRadius:12`, `padding:2`), bg `#34C759` on / `--sep-strong` off; 20×20 white knob (`borderRadius:50%`, shadow `0 1px 3px rgba(0,0,0,.3)`) sliding L↔R; `transition .15s`. → SwiftUI native `Toggle().tint(.green)`.

**SwiftUI**: a `Form`/`List`-grouped layout, or hand-rolled `VStack` of grouped cards to match the exact look.

---

## 5. Iconography

All icons are 20×20-viewBox stroke SVGs (`stroke-linecap/linejoin: round`), default `stroke 1.7`. Closest SF Symbol mappings below. Some are filled-dot or two-tone (`ellipsis`, flagged states). Prefer SF Symbols (`Image(systemName:)`) for native; the prototype names are arbitrary.

| Prototype name | Usage | SF Symbol |
|---|---|---|
| `house` | Heute nav | `house` |
| `calendar` | Kalender nav, agenda header | `calendar` |
| `bubbles` | Kombox nav, "Alle" filter | `bubble.left.and.bubble.right` |
| `people` | Kontakte nav, contact actions, accounts | `person.2` |
| `checklist` | Aufgaben nav, "Alle" smart card | `checklist` (or `list.bullet`) |
| `cardinbox` | CardInbox nav | `tray.and.arrow.down` (or `rectangle.stack`) |
| `gear` | Einstellungen nav | `gearshape` |
| `search` | SearchField | `magnifyingglass` |
| `plus` | add buttons | `plus` |
| `chevL` | back nav | `chevron.left` |
| `chevR` | forward / disclosure | `chevron.right` |
| `chevDown` | dropdown (unused in views) | `chevron.down` |
| `sidebar` | titlebar collapse toggle | `sidebar.left` |
| `mail` | Mail channel, actions | `envelope` |
| `message` | chat channels, actions | `message` |
| `phone` | call action | `phone` |
| `video` | video action | `video` |
| `star` | (defined, unused) | `star` |
| `flag` | flagged tasks/threads, "Markiert" | `flag` (filled → `flag.fill`) |
| `circle` | (defined, unused) | `circle` |
| `check` | task checkmark | `checkmark` |
| `checkCircle` | (defined, unused) | `checkmark.circle` |
| `paperplane` | composer send | `paperplane.fill` |
| `clock` | "Heute" smart card, early notes | `clock` |
| `pin` | event location | `mappin` (or `mappin.and.ellipse`) |
| `bell` | (defined, unused) | `bell` |
| `sun` | light-theme indicator, Darstellung icon | `sun.max` |
| `moon` | dark-theme indicator | `moon` |
| `ellipsis` | chat more-actions (filled dots) | `ellipsis` |
| `trash` | delete actions | `trash` |
| `archive` | mail archive | `archivebox` |
| `reply` | mail reply | `arrowshape.turn.up.left` |
| `attach` | attachments | `paperclip` |
| `qr` | biz-card QR, "digitale Visitenkarte" | `qrcode` |
| `building` | (defined, unused) | `building.2` |
| `globe` | (defined, unused) | `globe` |
| `map` | (defined, unused) | `map` |
| `contactcard` | (defined, unused) | `person.crop.rectangle` |
| `inboxdown` | "Automatisch zu Kontakten" | `tray.and.arrow.down` |

---

## Appendix: Tweaks Panel (out of scope)

`tweaks-panel.jsx` is a prototype-only floating dev panel (drag-to-move, `position:fixed` bottom-right, ~280px, translucent). It controls three runtime settings only: **theme** (Hell/Dunkel), **density** (Kompakt/Normal/Luftig), **sidebar style** (Klar/Akzent/Schlicht) — see `TWEAK_DEFAULTS` in `app.jsx`. It persists by posting `__edit_mode_set_keys` to a host bundler. **Do not port the panel.** Instead: theme → follow system `colorScheme` (with optional override), density → a global setting, sidebar style → a settings option (or drop to a single "klar" style). The accent is fixed (`#007AFF`/`#0A84FF`), not user-tweakable.
