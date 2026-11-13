---
name: Cockpit Streaming & In-Motion Media
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
  secondary: '#adc6ff'
  on-secondary: '#002e6a'
  secondary-container: '#0566d9'
  on-secondary-container: '#e6ecff'
  tertiary: '#6ed4f1'
  on-tertiary: '#003641'
  tertiary-container: '#2b9db9'
  on-tertiary-container: '#002e39'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdad8'
  primary-fixed-dim: '#ffb3af'
  on-primary-fixed: '#410006'
  on-primary-fixed-variant: '#930019'
  secondary-fixed: '#d8e2ff'
  secondary-fixed-dim: '#adc6ff'
  on-secondary-fixed: '#001a42'
  on-secondary-fixed-variant: '#004395'
  tertiary-fixed: '#b1ecff'
  tertiary-fixed-dim: '#6ed4f1'
  on-tertiary-fixed: '#001f27'
  on-tertiary-fixed-variant: '#004e5e'
  background: '#111317'
  on-background: '#e2e2e6'
  surface-variant: '#333538'
  surface-base: '#0D0F12'
  surface-card: '#1A1D24'
  surface-card-elevated: '#242832'
  text-primary: '#FFFFFF'
  text-secondary: '#94A3B8'
  text-tertiary: '#64748B'
  accent-crimson-glow: rgba(255, 0, 51, 0.35)
  accent-electric-glow: rgba(59, 130, 246, 0.35)
  glass-panel-overlay: rgba(26, 29, 36, 0.72)
  glass-border: rgba(255, 255, 255, 0.08)
typography:
  headline-xl:
    fontFamily: Space Grotesk
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.03em
  headline-xl-mobile:
    fontFamily: Space Grotesk
    fontSize: 30px
    fontWeight: '700'
    lineHeight: 38px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Space Grotesk
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Space Grotesk
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Space Grotesk
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  title-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  title-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 22px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: Space Grotesk
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 18px
    letterSpacing: 0.04em
  label-md:
    fontFamily: Space Grotesk
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.06em
  label-sm:
    fontFamily: Space Grotesk
    fontSize: 10px
    fontWeight: '500'
    lineHeight: 14px
    letterSpacing: 0.08em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-tablet: 1.5rem
  gutter-desktop: 2rem
  margin: 1.25rem
  margin-tablet: 2rem
  margin-desktop: 3rem
  space-xs: 0.375rem
  space-sm: 0.75rem
  space-md: 1.25rem
  space-lg: 1.75rem
  space-xl: 2.5rem
---

## Brand & Style

This design system delivers an automotive-grade, distraction-reduced media streaming interface engineered specifically for high-velocity in-cabin scenarios and dark environments. The visual atmosphere pairs ultra-deep pitch black surfaces with vibrant optical glows, evoking the cockpit instrumentation of modern performance vehicles and bespoke audio engineering hardware.

The design philosophy combines **Modern High-Contrast** architecture with restrained **Glassmorphic Hud Elements**:
- **Glanceability First:** Hierarchy is calibrated for split-second peripheral cognition. Primary interactive controls feature commanding scale, high contrast ratios (exceeding WCAG AAA for key actions), and immediate spatial feedback.
- **Pure Black Precision:** By grounding the canvas in deep OLED slate and pure dark values, visual fatigue during night driving is eradicated while battery life on mobile displays is optimized.
- **Neon Luminescence:** Focused crimson and electric accents provide crisp status indicators and dynamic media playback feedback through controlled backlights and soft neon glows rather than heavy structural borders.

## Colors

The palette establishes an uncompromising dark-mode-first environment tailored to automotive night vision, OLED depth, and crisp daytime sunlight legibility.

- **Primary (`#FF0033`):** High-energy racing crimson utilized strictly for live state indicators, primary playback triggers, track scrubbing heads, and active broadcast indicators.
- **Secondary (`#3B82F6`):** Electric precision blue deployed for contextual telemetry, connected vehicle audio channels, playlist metadata highlights, and secondary modes.
- **Neutral Base (`#0D0F12`):** Ultra-dark, blue-tinted void that prevents pixel light bleed and anchors all content.
- **Card Surfaces (`#1A1D24` & `#242832`):** Elevated charcoal slate tiers providing tangible layer separation without introducing disruptive white fills.
- **Typographic Scale:** Absolute pure white (`#FFFFFF`) for instantaneous track/channel recognition, supported by anti-glare slate grays (`#94A3B8` and `#64748B`) for auxiliary runtime and bitrate metadata.

## Typography

The type system balances industrial telemetry with natural reading ergonomics:
- **Headlines & Technical Labels (Space Grotesk):** Provides a technological, geometric aura echoing automotive HUDs and digital dashboards. Wide characters and distinct apertures keep metrics, track titles, and audio source tags legible under peripheral glance.
- **Body & Meta Information (Plus Jakarta Sans):** Delivers clean humanist geometric forms that prevent optical crowding when scanning lists, queues, or lyrics at arm's length.
- **Letter Spacing:** Extended tracking is enforced on small uppercase labels (`label-md`, `label-sm`) to retain legibility against pitch-black backgrounds and optical glow diffusions.

## Layout & Spacing

Layout geometry follows an expanded, reach-first fluid grid optimized for mobile and landscape mount positions:

- **Touch Margins & Hit Targets:** Mobile layouts honor an automotive touch baseline. Key action targets (play, skip, volume scrub, preset switches) must maintain a minimum physical footprint of 56px (with safe spacing of at least `space-sm` between adjoining elements) to ensure accurate taps during road vibration.
- **Rhythm & Grid:**
  - **Phone (Portrait / Landscape Mount):** 4 fluid columns; 1.25rem edge margin. Content stays within thumb-reach zones, keeping vital media controls in the lower 40% of the display.
  - **Tablet / Center Console Display:** 8 fluid columns; 1.5rem gutters; persistent driver-oriented navigation rail docked on the near edge.
  - **Desktop / In-Studio Dash:** 12 fluid columns; max-width 1440px centered; split panels for player queues, visualization decks, and contextual media data.

## Elevation & Depth

Visual depth is achieved through layered tonal luminance, glassmorphic frosted shields, and chromatic glows rather than heavy drop shadows:

- **Base Layer (L0):** Absolute background `#0D0F12`.
- **Card Tier (L1):** Slate tone `#1A1D24` accented with a microscopic 1px frosted top border (`rgba(255, 255, 255, 0.08)`) simulating an internal bevel lit by cabin light.
- **Floating HUD & Overlays (L2):** Glassmorphic surface built from `rgba(26, 29, 36, 0.72)` paired with a backdrop blur of `16px` to maintain contrast over video backgrounds.
- **Chromatic Glows:** Key interactive active states (e.g., active playhead, live audio equalizer, currently streaming stream card) cast an ambient, diffused radiance:
  - Crimson highlight: `0 0 24px rgba(255, 0, 51, 0.35)`
  - Electric blue highlight: `0 0 24px rgba(59, 130, 246, 0.35)`
- **Divider Treatment:** Physical line dividers are largely avoided; elevation shifts and `space-sm` dark channels define structural separation.

## Shapes

The design system employs a refined rounded geometry (Level 2) that marries technical precision with smooth tactile warmth:

- Standard controls, cards, and input fields utilize `0.5rem` (8px) corner radii.
- Media tiles and container cards scale to `1rem` (16px), harmonizing with curved in-car display bezels.
- Pill geometries are reserved strictly for high-visibility dynamic badges (e.g., LIVE chips, audio format tags like FLAC/DOLBY, and primary tactile play pills).

## Components

### Buttons
- **Primary Play / Action Button:** Pill-shaped or 1rem rounded container with `#FF0033` fill, white icon/label, and a subtle glowing back-diffusion (`0 8px 24px rgba(255, 0, 51, 0.4)`). Minimum height is 56px to guarantee effortless driving interaction.
- **Secondary / HUD Button:** Dark slate surface (`#242832`) with an ultra-thin 1px border (`rgba(255, 255, 255, 0.1)`), white label, and electric blue state highlight upon press or active toggle.
- **Ghost Utility Button:** Borderless, 48px square touch targets for quick audio skips, shuffle, and queue toggle. Text and icons sit in `#94A3B8`, brightening to `#FFFFFF` on press.

### Chips & Automotive Presets
- Preset selector chips utilize elevated dark containers (`#1A1D24`) with rounded pill contours.
- Selected state activates an Electric Blue (`#3B82F6`) outline, crisp white text, and a micro-glow accent.
- Inactive chips display `#94A3B8` typography with a subtle background highlight on touch.

### Lists & Queue Items
- Media queue rows feature generous vertical padding (minimum 64px row height) for stable fingertip targeting.
- Album thumbnails maintain a rounded 8px border with high contrast against the `#1A1D24` card backplate.
- Active playing item utilizes a vertical `#FF0033` left indicator bar and elevated slate card styling.

### Input Fields & Search
- Low-distraction pill or rounded rectangular inputs with dark slate backplate (`#1A1D24`), recessed `0 2px 4px rgba(0,0,0,0.5)` inner shadow, and light slate placeholder text (`#64748B`).
- Active focus invokes a vivid 1.5px `#3B82F6` focus halo with soft optical blur.
- Includes quick-clear tactile cross button and integrated voice search microphone affordance.

### Media & Video Cards
- 16:9 and 1:1 aspect containers featuring 16px corner rounding and a sub-surface gradient scrim (`rgba(13, 15, 18, 0.85)` at the bottom edge) ensuring video titles and durations remain legible over bright media covers.
- Progress scrub bars are heightened to 6px (expanding to 10px during scrub touch gestures) with high-visibility crimson fill and electric blue chapter markers.

### Radio & Toggle Controls
- Automotive toggle switches maintain oversized switch tracks (52px wide) with pure white thumbs and high-saturation blue/red fills for instant at-a-glance confirmation of driving modes, offline cache, and spatial audio modes.