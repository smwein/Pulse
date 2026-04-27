# Handoff: Pulse — AI Workout App

## Overview

Pulse is a mobile fitness app where every workout is generated and continuously adapted by an AI coach. Each workout has form-demo videos, real-time guidance during sessions, and a structured post-workout feedback loop that feeds back into the next session's plan. Four selectable coach personalities ("Ace" the friend, "Rex" the athlete, "Vera" the analyst, "Mira" the mindful) each have a distinct voice and accent color.

## About the Design Files

The files in this bundle are **design references created in HTML/JSX prototypes** — they show intended look, layout, copy, and behavior, but are NOT production code to copy directly. They use Babel-in-the-browser, global window-scoped components, and inline styles for prototyping speed.

Your job is to **recreate these designs in the target codebase using its established patterns and libraries**. If no codebase exists yet, the recommended target is **React Native + TypeScript** (since this is iOS-first and likely also Android later). All design tokens, component shapes, typography, and interactions documented below should be implemented natively in the chosen stack — don't render the HTML directly.

## Fidelity

**High-fidelity (hifi).** Final colors, typography, spacing, copy, and interactions are all decided. Recreate pixel-perfectly using the codebase's existing UI primitives. The dark warm-cinematic aesthetic is intentional and central to the brand — preserve it.

---

## Design System / Tokens

### Color (oklch)

All colors use `oklch()` for perceptual uniformity. The accent hue is a CSS variable that **shifts based on selected coach** — keep this dynamic.

```
--bg-0:   oklch(16% 0.005 60)   /* deepest background */
--bg-1:   oklch(20% 0.006 60)   /* card surface */
--bg-2:   oklch(24% 0.008 60)   /* raised surface */
--bg-3:   oklch(30% 0.01 60)    /* hover / active */
--line:       oklch(32% 0.008 60 / 0.6)   /* dividers, card border */
--line-soft:  oklch(40% 0.008 60 / 0.25)  /* internal dividers */

--ink-0:  oklch(97% 0.005 80)   /* primary text (paper white) */
--ink-1:  oklch(82% 0.008 80)   /* secondary text */
--ink-2:  oklch(64% 0.01 80)    /* tertiary / labels */
--ink-3:  oklch(46% 0.012 80)   /* placeholder / disabled */

/* Accent — hue varies per coach: Ace=45, Rex=25, Vera=220, Mira=160 */
--accent:      oklch(72% 0.18 var(--accent-h))
--accent-soft: oklch(72% 0.18 var(--accent-h) / 0.18)
--accent-ink:  oklch(20% 0.05 var(--accent-h))   /* text on accent fills */

--good: oklch(78% 0.14 150)     /* success */
--warn: oklch(78% 0.14 80)
```

### Typography

Three families. Load via Google Fonts or self-host equivalents.

| Variable      | Family                | Use                                |
|---------------|----------------------|------------------------------------|
| `--f-display` | Instrument Serif (italic, regular)  | Emotional moments, hero phrases  |
| `--f-sans`    | Inter Tight (400/500/600)           | All UI text                       |
| `--f-mono`    | JetBrains Mono                      | Numbers, eyebrow labels, data     |

**Type scale:**
- Eyebrow: 11px mono, letter-spacing 0.14em, uppercase, color `--ink-2`
- Body: 15px sans, line-height 1.45, color `--ink-1`
- Small: 13px sans, line-height 1.4, color `--ink-2`
- H3: 17px / 600 / -0.01em
- H2: 22px / 600 / -0.02em / 1.15
- H1: 28px / 600 / -0.02em / 1.1
- Display headlines: 32–52px, Instrument Serif italic for the emphasized phrase

**Number styling:** always use `font-variant-numeric: tabular-nums` and `font-feature-settings: "tnum"` for stat readouts (HR, kcal, time, weights).

### Radii

```
--r-sm: 10px    (small chips, thumbnails)
--r-md: 16px    (input fields)
--r-lg: 22px    (cards — primary)
--r-xl: 28px    (sheet/modal)
999px           (pills, buttons, icon buttons)
```

### Easing & motion

```
--e-out:  cubic-bezier(0.22, 1, 0.36, 1)   /* primary */
--e-in:   cubic-bezier(0.64, 0, 0.78, 0)
--e-soft: cubic-bezier(0.4, 0, 0.2, 1)
```

- Screen enter: 400ms `e-out`, fade + 8px translateY
- Slide-up: 450ms `e-out`, 24px translateY
- Sheet: 350ms `e-out`, translate from 110% bottom
- Stagger lists: 60ms increments, max 8 children

### Effects

- **Cards** are `bg-1` with 1px `--line` border and `--r-lg` corners. No drop shadows in the dark UI.
- **Glow** (used sparingly on coach avatar / generating states): `box-shadow: 0 12px 60px -12px oklch(72% 0.18 var(--accent-h) / 0.5)`
- **Grain overlay** on hero/cinematic sections: 6% opacity SVG noise, `mix-blend-mode: overlay`
- **Hero gradients**: 160° gradient from `oklch(34% 0.06 var(--accent-h))` → `oklch(20% 0.02 var(--accent-h))` → `oklch(15% 0.01 60)`, with two radial highlights at 30%/35% (warm) and 75%/70% (cool 280° hue)
- **Backdrop blur** on tab bar: `backdrop-filter: blur(24px) saturate(140%)`

---

## Core Components

### TopBar
Height 54px (60px on full-bleed screens to clear iOS notch). Three slots: left, title, right. Icon buttons are 38×38 circles (`bg-1` + `--line` border).

### Card
`bg-1` + 1px `--line` + `--r-lg`. Padding varies (12, 14, 16). Internal dividers use `--line-soft`.

### Pill
6×12 padding, 999px radius, `bg-2` + 1px `--line`, mono font, 12px, letter-spacing 0.04em.
Variant `is-accent`: `--accent-soft` background, `--accent` text, no border.

### Button (primary)
- Padding 14×22, radius 999px, sans 500/15px
- `bg: --accent`, `color: --accent-ink`
- Active: `transform: scale(0.97)`
- `btn-lg` modifier: 18×26 padding, 16px text
- `btn-block` for full-width

### Button (ghost)
Same shape, `bg-1` + `--line` border, `--ink-0` text.

### Tab bar
Floating pill at bottom (14px insets, 18px from bottom), `oklch(20% 0.006 60 / 0.78)` + backdrop-blur, 5 tabs (Home, Calendar, Library, Stats, Profile). Active tab: `bg-2` background, `--ink-0` icon. Tab height 44px.

### Coach Avatar
Circle, accent-tinted gradient based on coach hue. Letter mark from `coach.avatar` field. Used at sizes 28, 32, 56.

### Ring (progress)
SVG circle with two paths: `--line` track + `--accent` fill, `stroke-linecap: round`, animated via `stroke-dashoffset` 600ms `e-out`. Used for weekly minutes ring (Home), rest countdown (In-workout), session metrics.

### Exercise Placeholder (`<EP>`)
Stylized "pose" placeholder for exercise videos until real content lands. Background gradient + diagonal stripes + bottom-left mono caption (data-label). Always wrap in a `position: relative` box to contain its absolutely-positioned children.

---

## Screens

### 1. Onboarding (5 steps)
Full-bleed dark screens. 5 sequential steps, each with progress dots:
1. **Goals** (multi-select): Build strength / Lose body fat / Improve endurance / Move better / Manage stress / Longevity
2. **Level** (single): New to training / Regular / Experienced / Athlete (with sub-descriptions)
3. **Equipment** (multi): Bodyweight / Dumbbells / Kettlebells / Barbell+rack / Bench / Bands / Bike / Full gym
4. **Frequency** (single): 2–6+ sessions per week
5. **Coach pick** (single): 4 coach cards with avatar + role + blurb. Selection sets `--accent-h` globally.

CTA: "Continue" (primary) at bottom; "Back" icon button top-left.

### 2. Home / Today's Workout
- TopBar: greeting "Tuesday." + user avatar
- **Hero card** (full-width, `--r-lg`): cinematic hero gradient + grain, eyebrow "TODAY", title "Engine Builder", subtitle, stat strip (42 min · 9 moves · Zone 2), large play button
- **Coach "why" note**: card with avatar + 1–2 sentences explaining why this workout, today
- **Weekly ring**: 168 / 240 min ring, streak count, 12-day mini sparkline of session length
- **Week strip** (horizontal): Mon–Sun chips with day, date, type icon. Today is accent-filled. Past days: green check.
- **Quick actions row**: pill buttons — "Generate new", "Browse library", "Open coach"

### 3. AI Plan Generation
- Inputs: duration slider (15–90 min), focus segmented control (Strength / HIIT / Mobility / Recovery), vibe pills (multi: "fresh", "heavy", "fast", "calm")
- CTA "Generate plan" → transition to thinking state
- **Thinking state** (~1.9s): coach avatar inside pulsing accent ring, mono console-log lines streaming: `→ reading 1 session log`, `→ cross-checking 7 day load`, `→ adjusting Wed–Fri plan`
- **Result**: workout summary card + "Start workout" CTA + "Tweak" secondary

### 4. Workout Detail
- **Hero**: 360px tall, full-bleed cinematic placeholder + play overlay, eyebrow "Engine Builder · preview"
- **Stats strip**: 4-up grid of mono numbers (TIME, MOVES, ZONE, KCAL)
- **Blocks list**: warmup → main → finisher → cooldown sections, each block expanded showing exercises with 12px thumbnail, name, sets×reps, rest, focus tag
- **Sticky bottom bar**: "Start workout" primary button + "Save" ghost icon button

### 5. In-Workout (DATA-DENSE — the chosen variation)
Active workout tracking.

**Top bar:** close button, centered "SESSION 02:14:08" mono timer, bell icon. Session timer increments every second when playing.

**Progress segments:** Thin segmented bar showing all exercises. Past = solid accent, current = 50% accent, future = `bg-3`.

**Exercise card:**
- 96×96 PiP video thumbnail (left), play/pause overlay, "● FORM" mono badge top-left
- Right side: exercise eyebrow "Exercise 02 / 09", name (22px/600), focus subtitle, pills (sets, reps, accent-pill for load)

**Live metrics grid (3 columns, 1.4fr/1fr/1fr):**
- HEART RATE card: large mono accent number (bpm), 16-point sparkline polyline. Simulated live HR drifts ±2 bpm/sec, clamped 120–168.
- ZONE card: Z2/Z3/Z4 derived from HR, label below ("Easy", "Threshold", "Hard"), color-shifted hue
- KCAL card: cumulative burned

**Set log card:**
- Header: "SET LOG" eyebrow + "{n} / {total}" mono counter (must `nowrap` + `flexShrink: 0` to avoid wrap)
- Rows: grid 30px / 1fr / 1fr / 1fr / 30px = set number, reps, load, RPE, status icon
- Done sets: filled `--good` circle with check, ink-0 text
- Current set: `--accent-soft` row background, accent set number (600 weight), play icon
- Future sets: ink-3 text, empty 22px circle

**Coach whisper card:** small avatar + 12px italic line of cuing copy.

**Rest screen** (replaces set log when phase=rest):
- "REST" accent eyebrow
- 160px ring counting down rest seconds, large mono "MM:SS REMAINING" inside
- "Up next: set N of M" line
- "Skip rest" ghost button

**Bottom controls:** ghost back, primary "Log set N" (or "Start set N" during rest), ghost play/pause.

**State:**
- `idx` (current exercise index), `setNum` (current set 1..N), `phase` ('work' | 'rest'), `secs` (timer for current phase), `playing` (boolean), `setLog` (`{ [exId]: { [setNum]: {reps, load, rpe, done} } }`), `hr` (number)
- `logCurrentSet`: writes setLog entry, increments setNum or moves to next exercise; if last exercise+set, calls `onExit('complete')`
- Auto-transitions rest → work when `secs >= ex.rest`

### 6. Workout Complete (3-step feedback flow)

#### Step 1 — Recap (cinematic)
Full-bleed hero gradient with grain. "● COMPLETE" mono eyebrow top, then big italic-serif "That's a wrap." headline, body "42 minutes, 9 moves, 24 sets logged."
4-up stat grid: TIME 42:18 / AVG HR 138 / KCAL 388 / VOL 4.8t
Coach card: "{Coach}: Z3 work was clean. Quick check-in so I can dial in Wednesday's session."
CTA: "Give feedback →"

#### Step 2 — Rate (the feedback capture)
Scrollable form. State: `{ rating, intensity, mood, tags, exRatings, note }`.

- **Overall rating**: 5 star buttons (44×44, `--r-md`), filled accent up to selection
- **Intensity slider** (custom, 1–5): track + filled section + 5 dot handles. Active dot has 4px accent-soft halo. Labels: Way too easy / A bit easy / Just right / Tough / Brutal
- **Energy** (single, 2×2 grid): "Crushed it" / "Solid" / "Going through the motions" / "Rough day". Active card: `--accent-soft` bg, `--accent` border
- **Per-move thumbs**: card-list of first 4 exercises. Each row has 36px thumbnail (must have `position: relative`), name + sets/reps, then thumb-down + thumb-up 32×32 buttons. Active down: `oklch(70% 0.18 28 / 0.18)` bg + `--bad` color. Active up: `oklch(72% 0.16 150 / 0.18)` bg + `--good` color.
- **Quick tags** (multi): pill row — Loved the pace / Too long / Too short / More strength / More cardio / More mobility / Want fresh moves / Form felt clean / Form struggled / Low energy / Music was great / Got boring. Active: `--accent` border + `--accent-soft` bg + `--accent` text + leading "✓ "
- **Note**: textarea 80px min, `bg-1` + `--line`, "A note for {Coach} · optional" eyebrow
- **CTA** (sticky, top-bordered): "Send to {Coach} →" — disabled (40% opacity) until `rating > 0`

#### Step 3 — AI Adaptation Preview
- **Thinking phase** (~1.9s): coach avatar in pulsing 92px accent ring, "{Coach} IS THINKING" eyebrow, italic-serif "Tuning your plan…", left-aligned mono lines streaming.
- **Result phase**:
  - Headline "Here's what changes."
  - Coach card with derived summary line (varies by feedback — see logic below)
  - **Adjustments list** (max 4 cards): each has 32×32 accent-soft icon tile + label + detail. Adjustments are derived from feedback:
    - intensity ≥ 4 → "Dialing back load 5–7%"
    - intensity ≤ 2 → "Pushing load up 5%"
    - else → "Holding load"
    - tag too_long → "Shorter session" (-8 min)
    - tag too_short → "Adding a finisher" (+6 min conditioning)
    - tag more_strength → "More strength volume"
    - tag more_mobility → "Mobility added"
    - tag fresh_moves → "Fresh exercises" (rotate 3 in)
    - tag form_struggled → "Tempo work" (3-1-1, -10% load)
    - mood rough OR low_energy tag → "Recovery prioritized" (Wed becomes Z2 + mobility)
    - any down-rated exercises → "Replacing N moves"
    - if rating ≥ 4 and only 1 adjustment → add "Building on this"
  - **Next session preview card**: eyebrow "NEXT UP · WED", title, duration/move count, two pills ("RECOVERY", "NEW · BASED ON YOUR FEEDBACK")
  - CTAs: ghost check + primary "Done — see you Wednesday"

### 7. Calendar
Monthly grid, dot indicators per workout type. Tap day → mini-sheet with that day's workout summary.

### 8. Exercise Library
Search bar + filter chips (Strength / HIIT / Mobility / Recovery / Beginner / Intermediate / Advanced). List rows: thumbnail + name + focus + level pill.

### 9. Stats / Progress
Cards: Weekly minutes ring, Volume lifted, Zone distribution (5 horizontal bars Z1–Z5), PRs list, 12-week consistency dots.

### 10. Profile & Settings
Avatar + name, sections: Plan, Coach (with switch action), Equipment, Notifications, Health connections, Account, Sign out.

### 11. Coach Chat
Full-screen chat thread. Wired to live LLM in the prototype via `window.claude.complete({ messages })`. Each coach has a distinct system prompt (`coach.style`) so voice differs:
- **Ace**: warm, contractions, light humor
- **Rex**: imperative, short, no fluff
- **Vera**: cite numbers, HRV, RPE
- **Mira**: soft, breath-aware, sensory

Message bubbles: user right-aligned `--accent-soft`, coach left-aligned `bg-1` + `--line`. Composer is sticky bottom with rounded textarea + send icon button.

In production: route through your own LLM provider with system prompts derived from `COACHES[id].style` in `data.jsx`.

---

## State Management

Recommend Zustand or Redux Toolkit. Slices:

- **auth**: user, token
- **plan**: current week, today's workout, generation status
- **session**: in-progress workout state (idx, setNum, phase, secs, playing, setLog, hr) — should persist to local storage so users can resume
- **feedback**: post-workout form state, draft
- **coach**: selected coach id, message history
- **prefs**: theme, accent override, intensity dial, equipment, frequency

The post-workout feedback object is the **most important data the AI consumes** to adapt plans. Schema:

```ts
type WorkoutFeedback = {
  workoutId: string;
  completedAt: string;        // ISO
  rating: 1|2|3|4|5;
  intensity: 1|2|3|4|5;       // 1=way too easy, 5=brutal
  mood: 'great' | 'good' | 'ok' | 'rough';
  tags: string[];             // see RateStep tagOptions
  exRatings: Record<string, 'up' | 'down' | null>;
  note?: string;
  // derived metrics also sent
  avgHr: number;
  kcal: number;
  durationSec: number;
  setsLogged: { exId: string; reps: number; load: string; rpe: number }[];
};
```

---

## Interactions & Behavior

- **Coach switching**: changing the selected coach updates `--accent-h` CSS variable globally, which cascades through every accent-using element. Implement as a theme provider that injects the hue.
- **Rest auto-advance**: when `phase === 'rest'` and `secs >= ex.rest`, automatically transition back to `phase: 'work'`, reset `secs: 0`.
- **Set logging**: write to `setLog`, then either advance set number (and start rest) or jump to next exercise. After last exercise + last set, navigate to Complete flow.
- **HR simulation** (prototype only): `hr += random(-2, 2)`, clamp 120–168. In production, subscribe to HealthKit / Bluetooth HRM stream.
- **Plan generation**: prototype shows ~1.9s fake delay with mono console lines. In production: stream the LLM response or show a real progress indicator while the planning service runs.
- **Per-exercise thumbs**: tapping the same thumb again clears the rating (toggle). Both buttons are mutually exclusive within a row.
- **Star rating**: tap any star to set rating to that index. No half-stars.

---

## Accessibility

- All interactive elements need `accessibilityLabel` / `aria-label` (icon-only buttons especially)
- Star buttons should announce "{N} of 5 stars selected"
- Slider needs role=slider with min/max/now values
- Coach avatar + name should be a single touch target where appropriate
- Rest countdown ring needs an `aria-live="polite"` text equivalent
- Color contrast: ink-0 on bg-0 = 16.5:1, ink-1 on bg-0 ≈ 11:1, ink-2 on bg-0 ≈ 6.4:1 (all AA+). Accent on bg-0 ≈ 5.8:1 (AA for large text only — keep accent text at ≥17px).

---

## Assets

- **Fonts**: Inter Tight, Instrument Serif, JetBrains Mono — all available on Google Fonts
- **Icons**: 24×24 stroke-based icon set defined in `icons.jsx`. ~50 icons total. Either re-implement from those SVG paths or substitute with Lucide / Phosphor (closest match: Lucide).
- **Images**: All exercise/workout imagery in the prototype is placeholder. Real videos/thumbnails should be supplied by the content team.
- **Coach avatars**: currently letter-mark fallbacks. Replace with real coach photography or illustrations when available.

---

## Files in this Bundle

| File | Purpose |
|------|---------|
| `Pulse.html` | Root prototype — open this in a browser to see everything |
| `styles.css` | Full design token system + utility classes |
| `data.jsx` | Coach personalities, today's workout, week, stats, library, onboarding options — port to your data layer |
| `icons.jsx` | All icon SVG paths |
| `components.jsx` | Shared UI primitives (TopBar, Card, Headline, Ring, CoachAvatar, ExercisePlaceholder, etc.) |
| `screens/home.jsx` | Home / today's workout |
| `screens/onboarding.jsx` | 5-step onboarding |
| `screens/plangen.jsx` | AI plan generation flow |
| `screens/workoutdetail.jsx` | Workout detail + start screen |
| `screens/inworkout.jsx` | **Active session — data-dense variation (chosen)** |
| `screens/inworkout-variations.jsx` | Reference: 4 alternative in-workout layouts (cinematic, data-dense, minimal, etc.) |
| `screens/complete.jsx` | **3-step end-of-workout feedback flow** |
| `screens/misc.jsx` | Calendar, library, stats, profile, coach chat |
| `In-Workout Variations.html` | Side-by-side comparison page used during exploration |
| `ios-frame.jsx` / `tweaks-panel.jsx` / `design-canvas.jsx` | Prototype scaffolding — discard, not part of product |

## Recommended Implementation Order

1. Design tokens + theme provider (with dynamic accent hue)
2. Core primitives: Card, Button, Pill, IconButton, TopBar, TabBar, Ring, CoachAvatar
3. Data layer + types (port `data.jsx` to typed fixtures, then to API)
4. Onboarding → coach selection (sets the theme)
5. Home + Today's Workout
6. Workout Detail + Start flow
7. **In-Workout (data-dense)** — the centerpiece, build last
8. Complete feedback flow + plan adaptation API contract
9. Coach Chat (LLM integration)
10. Calendar / Library / Stats / Profile

## Notes on the Feedback → AI Loop

The 3-step Complete flow is the product's core differentiator. The adaptations list shown in Step 3 is **derived client-side from the feedback** in the prototype for demo purposes — in production, this should be:
1. Submit `WorkoutFeedback` to the planning service
2. Service updates the user's current plan and returns the diff
3. Show the actual adjustments the planner made (not pre-canned strings)
4. Cache the next session's preview card based on the response

The mock copy in `complete.jsx` (e.g. "Dialing back load 5–7%") is illustrative — production strings should reflect what the planner actually did.
