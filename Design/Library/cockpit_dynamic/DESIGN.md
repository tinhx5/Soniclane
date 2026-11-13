---
name: Cockpit Dynamic
colors:
  surface: '#111317'
  surface-dim: '#111317'
  surface-bright: '#37393d'
  surface-container-lowest: '#0c0e11'
  surface-container-low: '#1a1c1f'
  surface-container: '#1e2023'
  surface-container-high: '#282a2d'
  surface-container-highest: '#333538'
  on-surface: '#e2e2e6'
  on-surface-variant: '#e9bcb9'
  inverse-surface: '#e2e2e6'
  inverse-on-surface: '#2f3034'
  outline: '#b08784'
  outline-variant: '#5f3e3d'
  surface-tint: '#ffb3af'
  primary: '#ffb3af'
  on-primary: '#68000e'
  primary-container: '#ff5357'
  on-primary-container: '#5c000b'
  inverse-primary: '#bf0024'
  secondary: '#a5e7ff'
  on-secondary: '#003543'
  secondary-container: '#00d2ff'
  on-secondary-container: '#00566a'
  tertiary: '#adc6ff'
  on-tertiary: '#002e6a'
  tertiary-container: '#4d8eff'
  on-tertiary-container: '#00285d'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdad8'
  primary-fixed-dim: '#ffb3af'
  on-primary-fixed: '#410006'
  on-primary-fixed-variant: '#930019'
  secondary-fixed: '#b6ebff'
  secondary-fixed-dim: '#47d6ff'
  on-secondary-fixed: '#001f28'
  on-secondary-fixed-variant: '#004e60'
  tertiary-fixed: '#d8e2ff'
  tertiary-fixed-dim: '#adc6ff'
  on-tertiary-fixed: '#001a42'
  on-tertiary-fixed-variant: '#004395'
  background: '#111317'
  on-background: '#e2e2e6'
  surface-variant: '#333538'
typography:
  headline-xl:
    fontFamily: Space Grotesk
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-xl-mobile:
    fontFamily: Space Grotesk
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg:
    fontFamily: Space Grotesk
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 44px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Space Grotesk
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: 0em
  headline-md:
    fontFamily: Space Grotesk
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  title-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '700'
    lineHeight: 28px
  title-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '500'
    lineHeight: 26px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 22px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-lg:
    fontFamily: Space Grotesk
    fontSize: 16px
    fontWeight: '700'
    lineHeight: 20px
    letterSpacing: 0.04em
  label-md:
    fontFamily: Space Grotesk
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 18px
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Space Grotesk
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.08em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1.5rem
  gutter-compact: 1rem
  gutter-expanded: 2rem
  margin: 2rem
  margin-compact: 1rem
  margin-expanded: 3rem
  space-xs: 0.5rem
  space-sm: 0.75rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.5rem
---

## Brand & Style

This design system is engineered specifically for in-cabin automotive experiences where safety, extreme glanceability, and immersive media consumption converge. The interface lives in high-distraction, variable-light environments ranging from direct daylight glare to unlit night drives. 

### Core Aesthetic: Precision Performance OLED
The design merges modern automotive telemetry with high-fidelity media streaming. It borrows structural clarity from aviation heads-up displays (HUDs) and sleek ergonomics from luxury vehicle digital instrument clusters. 

- **Primary Metaphor:** The Active Cockpit. Information is clustered logically into glanceable visual blocks, stripping away ambient visual noise and decorative excess.
- **Visual Weight:** Solid, dense, high-contrast surfaces floating above true OLED absolute blacks to prevent driver eye fatigue and eradicate in-cabin light bleed.
- **Safety Priority:** Strict hit-target discipline where interaction targets never drop below 56px, accommodating rough road surfaces, arm reach, and rapid peripheral scanning.

## Colors

The palette is engineered for pure OLED contrast ratios, zero peripheral glare, and instantaneous status communication.

### Surface Tiers
- **OLED Canvas (`#0D0F12`):** Pure non-reflective deep base canvas. Maximizes battery efficiency on in-dash displays and creates endless depth.
- **Surface Level 1 (`#1A1D24`):** Base container cards, media trays, side navigation docks, and list item backdrops.
- **Surface Level 2 (`#242933`):** Elevated overlays, active player drawer sheets, scrubbing scrub-bars, and modal prompts.
- **Surface Level 3 / Stroke (`#333A48`):** Low-contrast dividers and crisp structural containment borders.

### Accents & Signatures
- **Primary Velocity Red (`#FF0033`):** The primary streaming anchor. Reserved strictly for active playback states, live broadcast indicators, YouTube video integration anchors, recording/buffering status, and primary call-to-action buttons.
- **Secondary Cyan Glow (`#00D2FF`):** Digital audio metrics, high-resolution/lossless audio indicators, EQ visualizations, and route/drive telemetry links.
- **Tertiary Electric Blue (`#3B82F6`):** Secondary interactive selections, playlist curation highlights, and voice-command activation rings.

### Typography & Readability
- **Absolute Text (`#FFFFFF`):** Song titles, artist primary headers, time remaining, and primary interface commands. Contrast ratio exceeds 15:1 against surfaces.
- **Muted Slate (`#94A3B8`):** Secondary metadata (album titles, bitrates, queue counts, duration timestamps).
- **Dim Inactive Slate (`#64748B`):** Disabled toggles, past track time markers, and inactive track indicators.

## Typography

Typography prioritizes sub-second cognitive acquisition. Drivers must parse title, artist, and playback states through peripheral vision in under 400 milliseconds.

- **Display & Labels (`Space Grotesk`):** Technical, geometric numerals and headers with distinct glyph shapes that resist blurring under vibration. Numbers and timing codes feature distinct width spacing to eliminate visual stutter during live playback counting.
- **Continuous Reading & Body (`Plus Jakarta Sans`):** Clean, open-counter grotesque designed for crystal-clear readability at short visual exposures. Large x-height preserves character distinction across low-resolution infotainment matrices.
- **Rule on Diminutive Text:** No touch target, label, or interactive element may feature text smaller than 14px while the vehicle is in gear. 12px is restricted exclusively to static metadata badges (e.g., "LOSSLESS", "4K", "EXPLICIT").

## Layout & Spacing

The layout is built on a high-density, horizontal-first automotive matrix. Rather than standard mobile-vertical grids, vehicle displays emphasize wide aspect ratios (16:9, 21:9, and ultrawide pillar-to-pillar configurations).

### Structural Architecture
- **Horizontal Split Anchor:** A persistent 80px–96px left-hand control rail (or right-hand for RHD markets) locks critical driving controls (Voice, Quick Play, Safety Override, Home) closest to the steering wheel.
- **Content Grid:** A 12-column adaptive fluid grid with generous gutters (`1.5rem` to `2rem`) to prevent mistaps between adjacent media cards during chassis roll.
- **Horizontal Carousels:** Media cards utilize snapping edge-to-edge carousels with peek margins to indicate content continuation without requiring vertical scrubbing.

### Safety Spacing Thresholds
- **Zero-Overlap Buffer:** Between any two standalone interactive controls, maintain a minimum gap of `space-md` (16px) to eliminate double-tap errors.
- **Edge Cushion:** Touch targets placed within 48px of physical screen bezels require expanded internal padding (`space-lg`) to account for finger collision with dashboard trim.

## Elevation & Depth

Automotive screens must avoid heavy, murky drop-shadows that wash out under sunlight or create visual clutter at night. Depth is rendered through calibrated tonal layers, optical borders, and selective photonic backglow.

### Surface Hierarchy
1. **Level 0 (Canvas, `#0D0F12`):** Base layer, dead black, infinite depth.
2. **Level 1 (Dock & Trays, `#1A1D24`):** Main card backgrounds, lateral menus. Edge-defined with a `1px` inner structural border of `#2D323E`.
3. **Level 2 (Active Elements & Modals, `#242933`):** Current playing card, contextual drawers, volume HUD popouts. Highlighted with a `1px` border of `#3B82F6` at 30% opacity.

### Photonic State Glows
Active controls emit focused, short-throw ambient glow instead of diffused drop-shadows:
- **Active Playback Glow:** `0 0 24px rgba(255, 0, 51, 0.35)` wrapping the primary transport control.
- **Voice/System Focus Glow:** `0 0 32px rgba(0, 210, 255, 0.25)` highlighting selected infotainment nodes during steering-wheel D-pad navigation.
- **Zero Cast Shadows:** Standard black drop-shadows (`box-shadow: 0 4px 6px rgba(0,0,0,...)`) are forbidden; they reduce surface separation on dark panels. Contrast must be achieved via luminosity shifts between `#1A1D24` and `#242933`.

## Shapes

The design system utilizes balanced structural curvature (`roundedness: 2`), delivering an athletic, performance-engineered visual cadence that mirrors automotive interior cockpit architecture.

- **Base Radii:** Standard cards, playback controls, and list row containers utilize `0.5rem` (8px) corners.
- **Interactive Buttons & Badges:** Primary transport triggers, filter pills, and quick-action buttons utilize `1rem` (16px) or fully rounded pill configurations (`9999px`) to immediately communicate pressability.
- **Album & Video Thumbnails:** Clipped at `0.5rem` (8px) to preserve edge definition and maximum preview area without aggressive circular crops cutting into album artwork or video thumbnails.

## Components

Every interactive component is built around the fundamental automotive rule: **minimum touch envelope of 56px × 56px**, regardless of icon or visual label footprint.

### Buttons
- **Primary Transport (Play/Pause):** 72px circular or pill target. Background `#FF0033`, content `#FFFFFF`. Emits active pulse glow when buffering. Minimum hit area: 72px × 72px.
- **Secondary Media Buttons (Skip, Shuffle, Repeat):** Minimum 56px × 56px touch envelope. Visual icon size: 28px. Inactive color: `#94A3B8`; active color: `#00D2FF`.
- **Driver Action Bars:** Floating or anchored 56px-tall pill buttons using `#242933` backgrounds with a `1px` border of `#3B82F6` (40% opacity).

### Chips & Source Selectors
- **Streaming Filter Chips:** 56px height for rapid selection during drive cycles (e.g., "YouTube Music", "Downloaded", "Podcasts", "Live Feeds").
- **Selected State:** Solid `#3B82F6` background with `#FFFFFF` text and bold font weight.
- **Resting State:** Transparent background, `2px` border in `#333A48`, text `#94A3B8`.

### Media Cards (Audio & Video)
- **Compact Drive Card:** Horizontal stack. Left: 64px × 64px rounded album art. Center: Two-line truncate for Title (White, 18px) and Artist (Slate, 14px). Right: Instant favorite heart toggle (56px touch boundary).
- **Video Card (Parked Mode Only):** 16:9 cinematic aspect ratio container with `#1A1D24` slate surface base. Prominent duration badge in bottom-right corner (`#0D0F12` with 80% opacity, 12px bold Space Grotesk). Features an automatic safety lock overlay when the vehicle shifts into gear.

### Lists & Queue Management
- **List Rows:** Minimum height of 72px to allow effortless finger landing. Separated by `1px` subtle lines (`#1F232B`).
- **Scrubbing & Slider Bars:** Track height is 6px, but touch grab zone expands invisibly to 48px vertical height. Played progress fills with `#FF0033` (video) or `#00D2FF` (high-res audio). The scrubber thumb is a distinct 20px circle that expands to 28px upon touch contact.

### Form Inputs & Voice Triggers
- **Search & Input Fields:** Minimum 56px height, filled with `#1A1D24`, text in `#FFFFFF`. Always paired with a dedicated 56px voice search button pinned to the right edge to discourage physical typing while vehicle is in motion.
- **Status Switches & Radios:** High-contrast toggles featuring a 32px thumb within a 60px track. Active fill shines in `#00D2FF` against a `#0D0F12` track background.