# Easify POS - Complete UI Modernization Plan

## Pixel-Perfect Redesign to Modern POS Aesthetic

---

## 1. EXECUTIVE SUMMARY

The current Easify app uses basic Material 3 with inconsistent styling: two conflicting color schemes (global `#2D7DD2` blue vs OrderScreen `#6366F1` indigo), hardcoded colors scattered across 30+ files, no centralized design system, and a hub-and-spoke navigation pattern that feels disconnected. This plan transforms it into a cohesive, premium POS application with a **collapsible dark sidebar** (on all screen sizes), consistent design tokens, polished micro-interactions, and a professional visual hierarchy. The Hub is the default screen on launch, and all widgets are responsive and scrollable.

---

## 2. NEW DESIGN SYSTEM - EXACT SPECIFICATIONS

### 2.1 Color Palette

#### Primary Brand Colors
| Token | Hex | Usage |
|-------|-----|-------|
| `primary` | `#6366F1` | Primary actions, active states, accents (unified from OrderScreen's indigo) |
| `primaryDark` | `#4F46E5` | Hover/pressed states on primary |
| `primaryLight` | `#EEF2FF` | Light primary backgrounds, tinted surfaces |
| `primaryContainer` | `#E0E7FF` | Card highlights, selected items |

#### Neutral / Surface Colors (Modern Slate)
| Token | Hex | Usage |
|-------|-----|-------|
| `surface0` | `#FFFFFF` | Main content background |
| `surface1` | `#F8FAFC` | Secondary background, scaffold bg |
| `surface2` | `#F1F5F9` | Input fills, disabled surfaces |
| `surface3` | `#E2E8F0` | Borders, dividers |
| `surface4` | `#CBD5E1` | Placeholder text, icons |
| `ink0` | `#0F172A` | Primary text, headings |
| `ink1` | `#1E293B` | Secondary text |
| `ink2` | `#475569` | Tertiary text, body |
| `ink3` | `#64748B` | Muted text, captions |
| `ink4` | `#94A3B8` | Disabled text, hints |
| `ink5` | `#CBD5E1` | Lightest text |

#### Sidebar (Dark Mode)
| Token | Hex | Usage |
|-------|-----|-------|
| `sidebarBg` | `#0F172A` | Sidebar background |
| `sidebarSurface` | `#1E293B` | Sidebar cards, hover |
| `sidebarActive` | `#6366F1` | Active nav item bg |
| `sidebarText` | `#F1F5F9` | Sidebar primary text |
| `sidebarMuted` | `#94A3B8` | Sidebar secondary text |
| `sidebarBorder` | `#334155` | Sidebar dividers |

#### Semantic Colors
| Token | Hex | Usage |
|-------|-----|-------|
| `success` | `#10B981` | Confirm, available, profit |
| `successLight` | `#D1FAE5` | Success backgrounds |
| `warning` | `#F59E0B` | Caution, busy |
| `warningLight` | `#FEF3C7` | Warning backgrounds |
| `danger` | `#EF4444` | Delete, error, loss |
| `dangerLight` | `#FEE2E2` | Error backgrounds |
| `info` | `#3B82F6` | Information, links |
| `infoLight` | `#DBEAFE` | Info backgrounds |

#### Cart Panel (Dark Indigo - keep from OrderScreen)
| Token | Hex | Usage |
|-------|-----|-------|
| `cartBg` | `#1E1B4B` | Cart background |
| `cartSurface` | `#2D2A5E` | Cart item surfaces |
| `cartText` | `#F1F5F9` | Cart primary text |
| `cartMuted` | `#94A3B8` | Cart secondary text |
| `cartAccent` | `#818CF8` | Cart accent/highlights |

### 2.2 Typography Scale

#### Font Family
- **Primary**: `Inter` (import via `google_fonts` package)
- **Monospace**: `JetBrains Mono` (for prices/numbers)

#### Type Scale
| Name | Size | Weight | Letter Spacing | Line Height | Usage |
|------|------|--------|----------------|-------------|-------|
| `display` | 28px | 700 (Bold) | -0.5px | 1.2 | Page titles, hero numbers |
| `headline` | 22px | 700 (Bold) | -0.3px | 1.3 | Section headings |
| `titleLg` | 18px | 600 (Semi) | -0.2px | 1.35 | Card titles, dialog titles |
| `titleMd` | 16px | 600 (Semi) | 0px | 1.4 | Subsection titles |
| `titleSm` | 14px | 600 (Semi) | 0px | 1.4 | List item titles, labels |
| `bodyLg` | 16px | 400 (Regular) | 0px | 1.5 | Body text |
| `bodyMd` | 14px | 400 (Regular) | 0px | 1.5 | Default body |
| `bodySm` | 12px | 400 (Regular) | 0.1px | 1.5 | Captions, secondary info |
| `labelLg` | 14px | 600 (Semi) | 0.3px | 1.2 | Button text |
| `labelMd` | 12px | 600 (Semi) | 0.5px | 1.2 | Badges, chips |
| `labelSm` | 10px | 600 (Semi) | 0.8px | 1.2 | Small badges, tags |
| `priceLg` | 20px | 700 (Bold) | -0.3px | 1.2 | Cart total, large prices |
| `priceMd` | 14px | 700 (Bold) | 0px | 1.2 | Item prices |
| `priceSm` | 12px | 600 (Semi) | 0px | 1.2 | Inline prices |
| `mono` | 14px | 500 (Medium) | 0px | 1.4 | Numeric displays, timers |

### 2.3 Spacing System (4px base grid)

| Token | Value | Usage |
|-------|-------|-------|
| `space0` | 0px | - |
| `space1` | 4px | Inline element spacing |
| `space2` | 8px | Tight spacing (icon + text) |
| `space3` | 12px | Related item spacing |
| `space4` | 16px | Standard padding, card gaps |
| `space5` | 20px | Section inner padding |
| `space6` | 24px | Section spacing, page padding |
| `space8` | 32px | Major section gaps |
| `space10` | 40px | Page top/bottom padding |
| `space12` | 48px | Hero spacing |

### 2.4 Border Radius

| Token | Value | Usage |
|-------|-------|-------|
| `radiusSm` | 6px | Badges, chips, small buttons |
| `radiusMd` | 10px | Input fields, small cards |
| `radiusLg` | 14px | Standard cards, dialogs |
| `radiusXl` | 18px | Feature cards, hero elements |
| `radiusFull` | 9999px | Pill shapes, avatars, FABs |

### 2.5 Shadows

| Token | Blur | Spread | Offset | Opacity | Usage |
|-------|------|--------|--------|---------|-------|
| `shadowSm` | 4px | 0 | (0,1) | 0.05 | Subtle lift (badges, chips) |
| `shadowMd` | 8px | 0 | (0,2) | 0.06 | Cards, elevated surfaces |
| `shadowLg` | 16px | 0 | (0,4) | 0.08 | Dialogs, popovers |
| `shadowXl` | 24px | 0 | (0,8) | 0.10 | Modals, floating panels |

### 2.6 Animation Timings

| Token | Duration | Curve | Usage |
|-------|----------|-------|-------|
| `instant` | 100ms | `easeOut` | Button press, toggle |
| `fast` | 200ms | `easeOut` | Hover, focus, micro-interactions |
| `normal` | 300ms | `easeInOut` | Page transitions, panel slides |
| `slow` | 500ms | `easeInOut` | Complex animations, transitions |

---

## 3. FILE-BY-FILE IMPLEMENTATION PLAN

### Phase 1: Foundation (Design Tokens & Theme)

#### 3.1 CREATE `lib/theme/app_colors.dart`
**Purpose**: Single source of truth for ALL color values.
**Action**: Create new file with all color constants from section 2.1.
```
- Replace every hardcoded Color(...) across the codebase with these tokens
- Remove all local _AppColors classes (order_screen.dart lines 24-40)
- Remove all Colors.grey[xxx], Colors.green, Colors.red.shadexxx references
```

#### 3.2 CREATE `lib/theme/app_typography.dart`
**Purpose**: Centralized text styles with Inter font.
**Action**: Create new file with TextTheme using `google_fonts` package.
- Add `google_fonts: ^6.1.0` to pubspec.yaml
- Define all text styles from section 2.2

#### 3.3 CREATE `lib/theme/app_spacing.dart`
**Purpose**: Spacing constants.
**Action**: Create new file with spacing values from section 2.3.

#### 3.4 CREATE `lib/theme/app_radius.dart`
**Purpose**: Border radius constants.
**Action**: Create new file with radius values from section 2.4.

#### 3.5 CREATE `lib/theme/app_shadows.dart`
**Purpose**: BoxShadow presets.
**Action**: Create new file with shadow values from section 2.5.

#### 3.6 CREATE `lib/theme/app_theme.dart`
**Purpose**: Complete ThemeData definition using all tokens above.
**Action**: Create new file that builds ThemeData with:
- New ColorScheme using unified `#6366F1` primary
- AppBarTheme: transparent bg, no elevation, ink0 text
- CardTheme: surface0 bg, radiusLg radius, shadowMd, 1px border surface3
- ElevatedButtonTheme: primary bg, white text, radiusMd, full-width option
- TextButtonTheme: primary foreground, radiusMd
- InputDecorationTheme: surface2 fill, radiusMd border, ink3 hint, ink0 label
- NavigationRailTheme: custom sidebar styling
- DialogTheme: radiusXl, shadowXl, surface0 bg
- BottomSheetTheme: radiusXl top, surface0 bg
- SwitchTheme, CheckboxTheme, RadioTheme: primary accent
- SnackBarTheme: ink0 bg, white text, radiusMd

---

### Phase 2: Layout System (Sidebar Navigation)

#### 3.7 CREATE `lib/widgets/app_shell.dart`
**Purpose**: Persistent sidebar + main content area shell.
**Action**: Create new widget that wraps all screens.
- **Layout**: Row with fixed 260px sidebar + Expanded content area
- **Sidebar background**: `sidebarBg` (#0F172A)
- **Sidebar width**: 260px expanded, 72px collapsed (icon-only)
- **Sidebar toggle**: Always visible in ALL screen sizes — user can collapse/expand the sidebar at any breakpoint via a toggle button (hamburger icon at top of sidebar)
- **Content area**: `surface1` (#F8FAFC) background
- **Behavior**: Sidebar is collapsible on ALL screen sizes (mobile, tablet, desktop). Default state: expanded (260px) on desktop (>900px), collapsed (72px) on mobile/tablet (<900px). User can override at any time.

#### 3.8 CREATE `lib/widgets/sidebar_nav.dart`
**Purpose**: Dark sidebar navigation component — collapsible on ALL screen sizes.
**Action**: Create new widget.
- **Structure**:
  ```
  ┌──────────────────────┐
  │  [Logo] EASIFY       │  ← App branding (48px logo + title)
  │                      │
  │  ● Commande          │  ← Active: bg sidebarActive, white text, left 3px bar
  │  ○ Historique        │  ← Inactive: sidebarMuted text
  │  ○ Jeux              │
  │  ○ Dashboard         │
  │  ○ Gestion           │
  │  ○ Paramètres        │
  │                      │
  │  ──────────          │  ← Divider
  │  [Avatar] Admin      │  ← User info
  │  ● En ligne          │  ← Status dot (green)
  └──────────────────────┘
  ```
- **Collapse toggle**: Top of sidebar, hamburger/chevron icon (22px), toggles between expanded (260px) and collapsed (72px). Always visible on ALL screen sizes.
- **Nav items**: 48px height, 16px horizontal padding, border-radius 10px (on hover/active)
- **Active indicator**: 3px left bar (40px tall, border-radius 2px) + `sidebarActive` bg
- **Hover state**: `sidebarSurface` bg (#1E293B)
- **Icons**: 22px, outlined when inactive, filled when active
- **Text**: 14px, weight 500 (Medium) — hidden when collapsed, only icons shown
- **User avatar**: 36px CircleAvatar with user initial, colored bg — shown below nav items
- **Logout button**: bottom of sidebar, icon-only when collapsed, full label when expanded

#### 3.9 MODIFY `lib/router.dart`
**Action**: Update routing to use AppShell as the main wrapper.
- Wrap routes in ShellRoute with AppShell
- All screens render inside the content area
- **Default route**: Navigate to Hub screen on app launch (not Commande)

#### 3.10 MODIFY `lib/screens/navigation_hub_screen.dart`
**Action**: Transform into the "Hub" landing page — the DEFAULT screen shown on app launch.
- Remove the standalone AppBar
- The sidebar now provides navigation
- Keep the hub cards but restyle them to match new design tokens
- **Hub is the default/active screen** — router should navigate to Hub on launch, not Commande
- Hub card grid: 2 columns on mobile, 3 columns on tablet, 4 columns on desktop

---

### Phase 3: Core Screen Redesigns

#### 3.11 REDESIGN `lib/screens/order_screen.dart`
**Current**: Has its own _AppColors, basic grid layout, dark cart panel.
**Target**: Professional POS terminal layout with polished interactions.

**Specific pixel-level changes**:

**AppBar (lines 130-195)**:
- Remove custom AppBar, use a slim 56px header within content area
- Left: Breadcrumb navigation (categories > products)
- Right: Cart badge (pill shape, primary bg, white text)
- Background: `surface0`, 1px bottom border `surface3`

**Category Grid (lines 383-441)**:
- Grid gap: 12px → 16px
- Card aspect ratio: 0.75 → 0.85 (slightly taller)
- Card bg: `surface0`, border: 1px solid `surface3`
- Border radius: 16px → 14px
- Hover: shadow-md, border becomes primary (1px)
- Image area: top 60% of card, with gradient overlay at bottom
- Title: 14px SemiBold, ink0, bottom 40% of card
- Add subtle shadow: `shadowSm` (4px blur)

**Product Grid (lines 323-381)**:
- Grid gap: 12px → 16px
- Card aspect ratio: 0.55 → 0.65 (taller cards)
- Card bg: `surface0`, border: 1px solid `surface3`
- Border radius: 16px → 14px
- Image: top 55%, ClipRRect with radius 14px top
- Bottom section: 12px padding, name (14px SemiBold) + price (13px Bold primary)
- On tap: scale to 0.97 for 100ms (micro-interaction)
- Add to cart: floating "+" button at bottom-right corner (32px, primary bg, white icon)

**Cart Panel (lines 445-573)**:
- Keep dark indigo theme (cartBg `#1E1B4B`)
- Panel width (landscape): 300px → 340px
- Panel height (portrait): 300px → 320px
- Cart header: 56px height, receipt icon in 28px container (cartSurface bg, 8px radius)
- Cart items: 8px gap between items (was 3px vertical margin)
- Each cart item: 12px radius (was 12px), bg `cartSurface`
- Quantity controls: 28x28px buttons (was 5px padding), radius 8px
- Quantity text: 13px Bold, cartText
- Product name: 13px SemiBold, cartText
- Price: 12px Bold, `cartAccent` (#818CF8)
- Confirm button: 52px height (was 48px), radius 12px, primary bg, full width
- "Ticket Simple" button: 44px height, radius 12px, border 1px cartMuted at 30%

**Breadcrumb Bar (lines 290-321)**:
- Height: 44px (was auto)
- Left icon: 16px, ink3
- Label: 14px SemiBold, ink0
- Action button: primary text, 14px SemiBold
- Bottom border: 1px solid surface3

#### 3.12 REDESIGN `lib/screens/dashboard_screen.dart`
**Target**: Clean analytics dashboard with consistent card styling.

**Specific pixel-level changes**:

**Date/User Filter Row (lines 147-254)**:
- Container: bg `surface0`, radius 14px, border 1px `surface3`, padding 12px 16px
- Date picker: icon 16px ink3, text 14px Medium ink0, chevron 16px ink4
- User dropdown: same style as date picker
- Gap between selectors: 12px

**Metric Cards (lines 259-328)**:
- Card bg: `surface0`, radius 14px, border 1px `surface3`
- Card padding: 16px all around
- Icon container: 40x40px, radius 10px, 12% color alpha bg
- Icon: 20px, theme color
- Title: 12px Medium, ink3
- Value: 20px Bold, ink0
- Trend badge: 10px radius, 10% green/red bg, text 11px Bold
- Comparison label: 10px Regular, ink4
- Card shadow: `shadowSm`
- Gap between cards: 12px

**Chart Cards (lines 331-371)**:
- Same card styling as metrics
- Title: 16px SemiBold, ink0
- "Weekly" badge: 11px SemiBold, ink3, surface2 bg, radius 8px
- Chart height: 180px (keep)
- Grid line color: surface3 at 50% opacity

**FAB (lines 120-139)**:
- Background: `ink0` (#0F172A) → `sidebarBg`
- Height: 52px
- Border-radius: 14px (not full pill, slightly rounded)
- Icon: 20px, white
- Label: 13px SemiBold, white
- Shadow: shadowLg

#### 3.13 REDESIGN `lib/screens/history_screen.dart`
**Target**: Clean timeline feed with consistent card styling.

**Specific pixel-level changes**:

**Order Cards (lines 409-588)**:
- Card bg: `surface0`, radius 14px, border 1px `surface3`
- Card shadow: `shadowSm`
- Card margin: 8px horizontal, 6px vertical
- Icon container: 40x40px, radius 10px, success bg (or danger for deleted)
- Order number: 16px SemiBold, ink0
- Timestamp: 13px Regular, ink3
- Staff: 13px Regular, ink3
- Items count: 13px Regular, ink3
- Total: 16px Bold, success color
- Items list bg: `surface1`, radius 10px, padding 12px
- Print button: FilledButton, primary bg, radius 10px, 36px height
- Deleted state: dangerLight bg, danger border

**Party Cards (lines 274-406)**:
- Same card styling as order cards
- Icon container: indigo at 10% bg, radius 10px
- Post label: 15px SemiBold, ink0
- Tier/staff: 12.5px Regular, ink3
- Timer: 12.5px Regular, ink3
- Price: 15px Bold, ink0
- Status badge: 10.5px SemiBold, colored text on 10% colored bg, radius 20px

#### 3.14 REDESIGN `lib/screens/games_screen.dart`
**Target**: Modern game session grid with clear status indicators.

**Specific pixel-level changes**:

**Game Post Cards (lines 348-483)**:
- Card bg: color-coded (green/orange/blue at 5% opacity, not 10%)
- Card border: 1px solid color at 15% opacity
- Card radius: 14px
- Card elevation: 0 (flat with border, not shadow)
- Post label: 18px Bold, ink0
- Party number: 12px Medium, ink2
- Timer: 24px Bold (large mono font), ink0
- Price: 14px SemiBold, ink2
- Status: colored dot (8px) + label (12px SemiBold)
- Available state: success dot, "DISPONIBLE" text
- Busy state: warning dot, timer prominent
- Queue badge: "Suivant" text 10px, ink3
- Queue button: 28px icon button, primary bg, white icon

#### 3.15 REDESIGN `lib/screens/settings_screen.dart`
**Target**: Clean settings with modern NavigationRail.

**Specific pixel-level changes**:

**NavigationRail (lines 50-93)**:
- Width: 80px
- Selected icon: filled, primary color
- Unselected icon: outlined, ink3
- Selected label: primary color, 11px SemiBold
- Unselected label: ink4, 11px Regular
- Active indicator: 32x32px, primary at 10% bg, radius 10px

**Content Sections**:
- Section title: 18px SemiBold, ink0
- Subtitle: 13px Regular, ink3
- Form inputs: surface2 fill, radius 10px, 48px height
- Switch tiles: custom switch with primary active color
- Save buttons: full-width, 48px height, primary bg, radius 10px

#### 3.16 REDESIGN `lib/screens/management_screen.dart`
**Target**: Clean CRUD interface with modern tab design.

**Specific pixel-level changes**:

**Tab Bar (lines 87-169)**:
- Custom tab bar with 2 tabs
- Tab height: 48px
- Active tab: primary text, 3px bottom indicator (primary), 20px wide
- Inactive tab: ink3 text, no indicator
- Tab icons: 20px
- Tab text: 12px SemiBold

**Product List Items (lines 365-404)**:
- Item height: 72px
- Left image: 56x56px, radius 10px
- Name: 16px SemiBold, ink0
- Price: 14px Bold, primary
- Category: 12px Regular, ink3
- Selected state: primary border (2px), primaryLight bg

**FAB**:
- 56x56px, primary bg, white "+" icon (24px)
- Radius: full (pill shape)
- Shadow: shadowLg

---

### Phase 4: Widget-Level Redesigns

#### 3.17 REDESIGN `lib/widgets/product_card.dart`
**Target**: Modern product card with micro-interactions.

**Before**: Card with elevation 4, basic layout.
**After**:
```
┌────────────────────┐
│                    │
│   [Product Image]  │  ← Top 60%, ClipRRect radius 14px top
│                    │
├────────────────────┤
│  Product Name      │  ← 14px SemiBold, ink0, maxLines 1
│  25.00 DH          │  ← 13px Bold, primary color
│            [+]     │  ← 32x32px primary circle, bottom-right
└────────────────────┘
```
- Card: bg surface0, border 1px surface3, radius 14px
- Shadow: shadowSm (4px blur)
- On tap: scale 0.97 for 100ms then back
- "+" button: appears on hover/focus (desktop) or always visible (mobile)
- Hover state: border becomes primary, shadow becomes shadowMd

#### 3.18 REDESIGN `lib/widgets/category_card.dart`
**Target**: Modern category card.

**After**:
```
┌────────────────────┐
│                    │
│  [Category Image]  │  ← Top 65%, ClipRRect radius 14px top
│                    │
├────────────────────┤
│  Category Name     │  ← 14px SemiBold, ink0, maxLines 1
└────────────────────┘
```
- Same card styling as ProductCard
- Hover: slight scale + shadow increase

#### 3.19 REDESIGN `lib/widgets/insight_item.dart` (InfoCard)
**Target**: Premium metric card.

**After**:
```
┌──────────────────────────────┐
│  [■] Revenue          ↑ 12%  │  ← Icon container 40x40, trend badge pill
│                              │
│  1,250.00 DH                 │  ← 20px Bold, ink0
│  vs. yesterday               │  ← 10px Regular, ink4
└──────────────────────────────┘
```
- Card: bg surface0, border 1px surface3, radius 14px, shadow shadowSm
- Padding: 16px
- Icon container: 40x40px, radius 10px, 12% color bg
- Title: 12px Medium, ink3
- Value: 20px Bold, ink0
- Trend: pill shape (radius 20px), 10% green/red bg

#### 3.20 REDESIGN `lib/widgets/payment_dialog.dart`
**Target**: Premium payment modal.

**After**:
```
┌──────────────────────────────┐
│                              │
│     Paiement de la Commande  │  ← 18px SemiBold, ink0
│                              │
│  ┌────────────────────────┐  │
│  │   Total à Payer        │  │  ← Card with surface1 bg
│  │   125.00 DH            │  │  ← 28px Bold, ink0
│  └────────────────────────┘  │
│                              │
│  ┌────────────────────────┐  │
│  │ 💵 Montant Reçu        │  │  ← Input: surface2 fill, radius 10px
│  └────────────────────────┘  │
│                              │
│  ┌────────────────────────┐  │
│  │   Monnaie à rendre     │  │  ← Card with success bg
│  │   75.00 DH             │  │  ← 24px Bold, success color
│  └────────────────────────┘  │
│                              │
│  [Annuler]    [Valider]      │  ← TextButton + ElevatedButton
│                              │
└──────────────────────────────┘
```
- Dialog: bg surface0, radius 18px (radiusXl), shadow shadowXl
- Padding: 24px
- Total card: surface1 bg, radius 12px
- Input: 52px height, surface2 fill, radius 10px
- Change card: success or danger bg at 5% opacity
- Buttons: 48px height, radius 10px

#### 3.21 REDESIGN `lib/widgets/user_selection_dialog.dart`
**Target**: Premium user selection + PIN entry modal.

**After**:
- Dialog: bg surface0, radius 24px, shadow shadowXl, width 400px
- Title: 18px SemiBold, ink0
- User list items: 56px height, CircleAvatar 40px, primary bg
- PIN dots: 20px diameter (was 12-20px), primary fill or danger fill
- Keypad buttons: 64px diameter (was 48-70px), surface2 bg, radius full
- Keypad text: 20px SemiBold, ink0
- Action keys: surface3 bg, icon 18px
- Confirm key: success bg at 10%, success icon

#### 3.22 REDESIGN `lib/widgets/admin_pin_dialog.dart`
**Target**: Premium admin PIN modal.

**After**:
- Same structure as UserSelectionDialog
- Icon header: 48px primary container, primary icon
- PIN dots: 20px, primary fill
- Keypad: 64px buttons

#### 3.23 REDESIGN `lib/widgets/charts.dart`
**Target**: Refined chart cards.

**After**:
- Card: bg surface0, border 1px surface3, radius 14px, padding 20px
- Title: 16px SemiBold, ink0
- Total: 24px Bold, ink0
- Trend badge: radius 8px (was 6px), 10% bg
- "Weekly" badge: surface2 bg, radius 8px, 11px SemiBold ink3
- Grid lines: surface3 at 50%
- Line stroke: 2.5px (was 3px)
- Bar width: 14px (was 16px)
- Day labels: 10px Medium, ink4

#### 3.24 REDESIGN `lib/widgets/category_card.dart` (management overlay buttons)
**After**:
- Edit/Delete buttons: 28x28px (was auto), surface0 bg at 90%, radius 8px
- Icon: 14px, edit=primary, delete=danger
- Appear on hover/focus only (desktop), always visible (mobile)

#### 3.25 REDESIGN `lib/widgets/product_item.dart` (management list item)
**After**:
- Height: 80px (was auto)
- Image: 60x60px, radius 10px
- Name: 16px SemiBold, ink0
- Price: 14px Bold, primary
- Selected: primary border 2px, primaryLight bg, elevation 0

#### 3.26 REDESIGN `lib/widgets/store_config.dart`
**After**:
- Form inputs: 52px height, surface2 fill, radius 10px
- Icons: 20px, ink3
- Labels: 14px Medium, ink0

#### 3.27 REDESIGN `lib/widgets/business_day_filter.dart`
**After**:
- Container: surface0 bg, border 1px surface3, radius 10px
- Date text: 14px SemiBold, ink0
- Chevron buttons: 32x32px, surface2 bg, radius 8px
- Arrow icons: 18px, ink3

#### 3.28 REDESIGN `lib/widgets/business_day_settings.dart`
**After**:
- Time picker inputs: surface2 fill, radius 10px, 48px height
- Labels: 14px Medium, ink0

#### 3.29 REDESIGN `lib/widgets/games_settings_section.dart`
**After**:
- Game post cards: surface0 bg, border 1px surface3, radius 14px
- Tier cards: same styling
- Add buttons: primary outlined

#### 3.30 REDESIGN `lib/widgets/expense_tracking.dart`
**After**:
- List items: 64px height, surface0 bg, border 1px surface3, radius 12px
- Icon: 32x32px container, radius 8px, danger at 8% bg
- Title: 14px SemiBold, ink0
- Amount: 14px Bold, danger
- Date: 12px Regular, ink3

#### 3.31 REDESIGN `lib/widgets/bestSellr.dart`
**After**:
- Card: surface0 bg, border 1px surface3, radius 12px
- Shadow: shadowSm

#### 3.32 REDESIGN `lib/widgets/dialog.dart`
**After**:
- Dialog: surface0 bg, radius 18px, shadow shadowXl

#### 3.33 REDESIGN `lib/widgets/daily_funds_dialog.dart`
**After**:
- Warning icon: 40px, warning color
- Input: surface2 fill, radius 10px, 52px height
- Buttons: primary bg, radius 10px

#### 3.34 REDESIGN `lib/widgets/comment_dialog.dart`
**After**:
- Dialog: surface0 bg, radius 18px
- Textarea: surface2 fill, radius 10px, min 100px height

#### 3.35 REDESIGN `lib/widgets/activation_dialog.dart`
**After**:
- Dialog: surface0 bg, radius 18px
- Input: surface2 fill, radius 10px, 52px height

---

### Phase 5: Snackbar & Micro-interactions

#### 3.36 STANDARDIZE ALL SNACKBARS
**Current**: Various hardcoded colors (green, red, orange).
**After**:
- Success: `success` bg, white text, check_circle icon, radius 10px
- Error: `danger` bg, white text, error icon, radius 10px
- Warning: `warning` bg, white text, warning icon, radius 10px
- Info: `ink0` bg, white text, info icon, radius 10px
- Behavior: floating, margin 16px, padding 12px 16px

#### 3.37 ADD MICRO-INTERACTIONS
- **Button press**: scale to 0.97 for 100ms
- **Card tap**: scale to 0.98 for 100ms
- **Tab switch**: animated indicator slide (300ms easeInOut)
- **Dialog open**: scale from 0.95 to 1.0 + fade (200ms easeOut)
- **Snackbar**: slide up from bottom (300ms easeOut)
- **Cart item add**: brief scale pulse (1.0 → 1.05 → 1.0, 200ms)
- **Quantity change**: number fade transition

---

### Phase 6: Responsive Design

#### 3.38 RESPONSIVE BREAKPOINTS
| Breakpoint | Width | Layout |
|------------|-------|--------|
| Mobile | < 600px | Collapsed sidebar (72px) + full-width content |
| Tablet | 600-900px | Collapsed sidebar (72px) + content |
| Desktop | > 900px | Expanded sidebar (260px) + content |

**Sidebar**: Always present on ALL screen sizes. Collapsed (72px, icon-only) by default on mobile/tablet. Expanded (260px) by default on desktop. User can toggle collapse/expand at any breakpoint via the sidebar toggle button.

#### 3.39 RESPONSIVE GRID ADJUSTMENTS
**Category Grid**:
- Mobile: 2 columns, 12px gap
- Tablet: 3 columns, 16px gap
- Desktop: 4 columns, 16px gap

**Product Grid**:
- Mobile: 2 columns, 12px gap
- Tablet: 3 columns, 12px gap
- Desktop: 4-5 columns, 16px gap

**Dashboard Metrics**:
- Mobile: 1 column (stacked)
- Tablet: 2x2 grid
- Desktop: 4 columns in a row

**Games Grid**:
- Mobile: 2 columns
- Tablet: 3 columns
- Desktop: 4 columns

#### 3.40 SCROLLABLE WIDGETS
All content areas must be scrollable when content overflows the viewport:
- **Main content area**: Wrap in `SingleChildScrollView` or `CustomScrollView` with `AlwaysScrollableScrollPhysics`
- **Product/Category grids**: Use `GridView` with `shrinkWrap: false` + `NeverScrollableScrollPhysics` on the grid itself; let parent `SingleChildScrollView` handle scrolling
- **Dashboard**: `SingleChildScrollView` wrapping all metric cards and charts
- **History list**: `ListView.builder` with automatic scrolling
- **Games grid**: `GridView` inside `SingleChildScrollView`
- **Settings**: `SingleChildScrollView` wrapping all form sections
- **Cart panel**: `ListView.builder` for cart items with `Expanded` to fill available space
- **Sidebar nav**: Fixed height, no scroll needed (items fit within viewport)
- All scroll views must use `physics: AlwaysScrollableScrollPhysics()` to ensure scrollability even when content fits

---

## 4. IMPLEMENTATION ORDER

### Priority 1 (Foundation - Do First)
1. Add `google_fonts` to pubspec.yaml
2. Create `lib/theme/` directory with all token files (3.1-3.6)
3. Update `lib/main.dart` theme definition (3.6)

### Priority 2 (Layout)
4. Create `lib/widgets/app_shell.dart` (3.7)
5. Create `lib/widgets/sidebar_nav.dart` (3.8)
6. Update `lib/router.dart` (3.9)
7. Update `lib/screens/navigation_hub_screen.dart` (3.10)

### Priority 3 (Core POS Screen)
8. Redesign `lib/screens/order_screen.dart` (3.11)
9. Redesign `lib/widgets/product_card.dart` (3.17)
10. Redesign `lib/widgets/category_card.dart` (3.18)
11. Redesign `lib/widgets/payment_dialog.dart` (3.20)

### Priority 4 (Other Screens)
12. Redesign `lib/screens/dashboard_screen.dart` (3.12)
13. Redesign `lib/widgets/insight_item.dart` (3.19)
14. Redesign `lib/widgets/charts.dart` (3.23)
15. Redesign `lib/screens/history_screen.dart` (3.13)
16. Redesign `lib/screens/games_screen.dart` (3.14)
17. Redesign `lib/screens/management_screen.dart` (3.16)
18. Redesign `lib/screens/settings_screen.dart` (3.15)

### Priority 5 (Remaining Widgets)
19. Redesign all remaining widgets (3.21-3.35)
20. Standardize snackbars (3.36)
21. Add micro-interactions (3.37)
22. Responsive polish (3.38-3.39)

---

## 5. COMPLETE COLOR REPLACEMENT MAP

Every hardcoded color in the codebase must be replaced:

| Current (File:Line) | New Token |
|---------------------|-----------|
| `Color(0xFF2D7DD2)` (main.dart:73) | `AppColors.primary` (#6366F1) |
| `Color(0xFFEDF5FC)` (main.dart:77) | `AppColors.primaryLight` (#EEF2FF) |
| `Color(0xFF210124)` (main.dart:78) | `AppColors.ink0` (#0F172A) |
| `Color(0xFFF8FAFC)` (order_screen.dart:25) | `AppColors.surface1` |
| `Color(0xFF0F172A)` (order_screen.dart:27) | `AppColors.ink0` |
| `Color(0xFF64748B)` (order_screen.dart:28) | `AppColors.ink3` |
| `Color(0xFFCBD5E1)` (order_screen.dart:29) | `AppColors.ink5` |
| `Color(0xFF6366F1)` (order_screen.dart:30) | `AppColors.primary` |
| `Color(0xFFEEF2FF)` (order_screen.dart:31) | `AppColors.primaryLight` |
| `Color(0xFFEF4444)` (order_screen.dart:32) | `AppColors.danger` |
| `Color(0xFFFEF2F2)` (order_screen.dart:33) | `AppColors.dangerLight` |
| `Color(0xFF10B981)` (order_screen.dart:34) | `AppColors.success` |
| `Color(0xFFE2E8F0)` (order_screen.dart:35) | `AppColors.surface3` |
| `Color(0xFF1E1B4B)` (order_screen.dart:36) | `AppColors.cartBg` |
| `Color(0xFF2D2A5E)` (order_screen.dart:37) | `AppColors.cartSurface` |
| `Color(0xFFF1F5F9)` (order_screen.dart:38) | `AppColors.cartText` |
| `Color(0xFF94A3B8)` (order_screen.dart:39) | `AppColors.cartMuted` |
| `Colors.grey[600]` (dashboard:172) | `AppColors.ink3` |
| `Colors.grey[700]` (dashboard:182) | `AppColors.ink2` |
| `Colors.grey.shade400` (history:242) | `AppColors.ink4` |
| `Colors.grey.shade600` (history:247) | `AppColors.ink3` |
| `Colors.grey.shade100` (history:303) | `AppColors.surface2` |
| `Colors.grey.shade50` (history:532) | `AppColors.surface1` |
| `Colors.green.shade600` (history:285) | `AppColors.success` |
| `Colors.red.shade600` (history:58) | `AppColors.danger` |
| `Colors.blue.shade100` (games:367) | `AppColors.infoLight` |
| `Colors.orange.shade100` (games:369) | `AppColors.warningLight` |
| `Colors.green.shade100` (games:370) | `AppColors.successLight` |
| `Color(0xFF1E293B)` (insight_item:105) | `AppColors.ink0` |
| `Colors.black.withOpacity(0.03)` (insight_item:35) | `AppColors.shadowMd` |

---

## 6. PUBSPEC.YAML CHANGES

Add to dependencies:
```yaml
dependencies:
  google_fonts: ^6.1.0  # For Inter font family
```

---

## 7. VERIFICATION CHECKLIST

After implementation, verify:
- [ ] All screens use sidebar navigation (no standalone AppBars)
- [ ] Sidebar is collapsible on ALL screen sizes (mobile, tablet, desktop)
- [ ] Sidebar toggle button works at every breakpoint
- [ ] Hub is the default screen shown on app launch
- [ ] All colors come from AppColors (zero hardcoded Color values)
- [ ] All text styles come from AppTypography
- [ ] All border radii use AppRadius tokens
- [ ] All shadows use AppShadows tokens
- [ ] All spacings follow 4px grid
- [ ] All content areas are scrollable when content overflows
- [ ] No widget causes overflow on any screen size
- [ ] OrderScreen cart panel is visually polished
- [ ] Dashboard metrics cards have consistent styling
- [ ] History cards have proper visual hierarchy
- [ ] Game post cards show clear status indicators
- [ ] Settings NavigationRail is properly styled
- [ ] All dialogs have consistent radius (18px) and shadow
- [ ] All snackbars follow the standard pattern
- [ ] Micro-interactions work (button press, card tap)
- [ ] Responsive layout works on mobile/tablet/desktop
- [ ] No layout overflow errors on any screen size
- [ ] Lint passes with zero warnings
