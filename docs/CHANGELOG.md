# CHANGELOG — Frontend Overhaul

Quick-scan list of what changed and why, in the order it happened. For full detail (paper section mapping, defect IDs, exact tokens) see [`PAPER_DELTA.md`](PAPER_DELTA.md) — this file is the short version so we don't lose track mid-work.

**Legend:** ✅ done · 🔄 in progress · ⬜ queued

---

## Phase 0 — Docs
- ✅ `CLAUDE.md` — architecture map, design-system rules, hard constraints for future sessions
- ✅ `docs/PAPER_DELTA.md` — tracks every deviation from `NEW APPSTONE.docx`

## Phase 1 — Design system foundation
- ✅ `lib/theme/` — colors, typography (Plus Jakarta Sans, bundled), spacing, breakpoints, motion, light+dark `ThemeData`
- ✅ Shared widgets — `AppScaffold`, `AppSection`, `AppTwoColumn`, loading/error/empty states, skeletons, `AppDialog`, chart primitives (score dial, radar, progress ring)
- ✅ `google_fonts`, `flutter_animate`, `fl_chart` added

## Phase 2 — Navigation shell + Home
- ✅ `AppShell` — adaptive nav (bottom bar / rail / extended rail)
- ✅ Home rebuilt — progress band, workflow preview, continue-card, feature grid recolored with real module accents
- ✅ Premium upsell screen (replaces the old snackbar)

## Phase 3 — Student screens (in progress)
- ✅ Login — split branded layout, inline field errors
- ✅ Defense Practice, Defense Results (score dial + radar + rank badge), Defense Session (two-column, timer ring)
- ✅ Paper Checker — two-column, PDF export
- ✅ **PDF export** — `lib/services/report_printer.dart` (defense results + paper check)
- 🔄 Manual, Title Generator, AI Workflow, Defense Context, both history screens — **restyled colors only, layout/structure/copy untouched per your instruction**

### Fixes along the way
- ✅ **Dark mode, properly** — all 13 remaining screens moved off the legacy `lib/app_colors.dart` (deleted) onto brightness-aware tokens. 118 refs remapped, hardcoded light tints replaced, `Colors.green/orange` → `success`/`warning` tokens
- ✅ **Nav reordered & trimmed** — `Home → Manual → Practice → Workflow → Checker`. Progress tab removed (history still reachable from the Practice/Checker app bars)
- ✅ **Theme toggle on every screen**, not just Home/Login
- ✅ **Neutral app bars** (maroon = brand/buttons only, not headers) + accent line under each
- ✅ **Flat cards with hairline borders** (shadows are invisible in dark mode)
- ✅ **Shared-axis page transitions**, theme-switch crossfade
- ✅ **Rounded icon set** standardized app-wide (~140 icons)
- ✅ **Fixed dead-end navigation bug** — opening a module from a Home card used to push it *over* the shell (bottom bar vanished, no back button). Now Home cards switch shell tabs directly via `AppShellScope`; genuinely-pushed screens (Title Generator, sessions, history) get their back button automatically

## Phase 4 — Admin portal
- ⬜ Not started. Your instruction: leave admin screens as-is for now (color migration only, done above)

## Phase 5 — Platform / polish
- ✅ Viewport meta tag, theme-color, real description in `web/index.html`
- ✅ Removed the floating PWA install button
- ⬜ Branded loading splash
- ⬜ Manifest orientation fix (`portrait-primary` → `any`)

## Animation / polish pass
- ✅ **Staggered entrance** extended to Manual, AI Workflow (setup + plan), Defense Context, Session History, Paper Check History. Deliberately *coarse* — 2–3 groups per screen, not one step per card, so a 15-phase plan or a long history list doesn't take a full second to finish arriving, and re-filtering doesn't replay the chain
- ✅ **Progress bars sweep to value** — new `AnimatedProgressBar` in `app_motion_widgets.dart`, wired into AI Workflow completion, Paper Checker rubric rows, and the defense question tracker
- ✅ **Press feedback** on Home feature cards — added to `_HoverLift` via `Listener` (not `GestureDetector`, which would fight the `InkWell` for the tap and kill the ripple)
- ✅ **Empty-state gentle motion** — icon drifts on a 4s cycle. Applied to *empty* states only; error states stay still on purpose, since a floating error icon reads as playful
- ✅ **Branded pull-to-refresh** — Home indicator now uses brand colours (see caveat below)

### Already animating before this pass (verified, no work needed)
- `ScoreDial` — arc **and** number both count up (defense results, paper checker)
- `ProgressRing`, `MetricBar` — already tween to value
- `NavigationBar` indicator — Material 3 animates the pill natively

## Defects found and fixed during self-audit
- ✅ **Shell pre-built all premium upsells at launch** for free users — 3 extra widget trees built before they were ever opened, and their entrance animations played invisibly, so the animation was already over by the time the tab was tapped
- ✅ **Animations ran in background tabs** — `IndexedStack` keeps every visited destination alive and does *not* pause tickers. A shimmering skeleton or breathing empty state in a background tab animated forever. Wrapped destinations in `TickerMode(enabled: i == _index)`
- ✅ **Theme crossfade was half-broken** (my own earlier bug) — `AnimatedTheme` lerped Material's colours, but `AppColors` read theme *brightness*, which flips at t=0.5. Backgrounds faded while text/accents snapped mid-fade. Fixed properly: `AppColors` is now a `ThemeExtension`, which `ThemeData.lerp` interpolates automatically, so every token fades together. `of()` keeps a brightness fallback so the bare-`MaterialApp` widget tests still pass
- ✅ **Accent line was on only 4 of 12 screens** — it appeared and disappeared while tab-switching. Extracted `appBarAccent()` and applied it everywhere

## Capstone Manual — reading treatment
- ✅ Body 17px / line-height 1.7, measure narrowed 760 → **660px** (~68 chars)
- ✅ Lead paragraph renders larger to give the eye an entry point
- ✅ Bullets: one card with accent markers, replacing one-`Card`-per-item (an 8-point list was 8 stacked boxes)
- ✅ **A- / A+ text size control**, 4 steps, persisted (`manual_text_scale_v1`). Scoped to the manual only — raising it does not stretch the nav bar or admin tables
- ✅ **Reading progress bar** doubling as the module accent line
- ✅ **Requirement callouts** — items stating an obligation get a tinted block. Matched on wording the manual already uses (`must`, `required`, `shall`, `not allowed`, `mandatory`); anything unmatched renders as a normal bullet, so emphasis changes but never meaning

## Contrast / WCAG AA audit
Measured with a real contrast script (kept at `tool/contrast_audit.dart` — re-run it after any palette change):

```bash
dart tool/contrast_audit.dart
```

**Result: both themes now pass AA (4.5:1) on every text/surface pair.** Failures found and fixed:

| Pair | Was | Now |
|---|---|---|
| `textTertiary` on background (light) | **2.83** ✗ | 4.65 |
| `textTertiary` on surface (dark) | 3.82 ✗ | 5.09 |
| white on `brand` fill (dark) — *every primary button label* | 3.55 ✗ | 5.07 |
| white on `premium` fill (dark) | **1.91** ✗ | 6.4+ |
| white on `success` / `warning` / `info` fill (dark) | 1.74 – 2.32 ✗ | all pass |
| `warning`, `premium`, `moduleTitleGen` on surface (light) | 4.06 – 4.34 ✗ | 4.9 – 5.4 |
| `success` / `premium` on their tints (light) | 4.43 ✗ | 4.52 / 4.55 |

**Root cause of the worst ones:** `onColor` and `onBrand` were white in *both* themes, but dark-theme accents are deliberately light colours — so white-on-accent was unreadable. Dark theme now uses dark ink on filled accents, which is also what Material 3 prescribes.

**New token: `onBrandStrong`** (white in both themes). Needed because `brandStrong` is a deep maroon in both themes, so the app-bar brand marks and rail logo still need white — flipping `onBrand` to dark ink alone would have broken them.

**Login brand panel** now pins to the light palette's maroons in both themes. Following the theme made its gradient run to a pale salmon in dark mode, where neither white nor dark ink cleared AA across the whole sweep.

## Still queued
- ⬜ Hero transition from Home cards *(you picked this — highest risk, doing it alone and last)*
- ⬜ Icon rule formalised: rounded = active/primary, outlined = idle/secondary *(decided; mostly matches current code, needs a documentation pass + spot fixes)*
- ⬜ Scroll-linked app bar elevation
- ⬜ Skeleton → content crossfade
- ⬜ Full custom pull-to-refresh drawing the Appstone mark
- ⬜ Desktop density pass

### Scope notes / judgement calls
- **Title Generator was left out of the stagger sweep.** Its chip layout is hand-measured with a `TextPainter` and guarded by 4 widget tests where an overflow fails the build. Not worth the risk for an entrance animation.
- **Admin screens untouched**, per your instruction to leave them as-is. That also means the "admin stat cards" half of the animated-counters pick is off the table.
- **Animated counters:** the scores you'd actually notice (`ScoreDial`) already counted up before this pass, so there was nothing left to wire once admin was excluded.
- **Pull-to-refresh** is branded by colour only. `RefreshIndicator` takes no child widget, so drawing the Appstone mark means replacing it with a custom sliver — a real change to scroll behaviour, not polish. Left queued rather than rushed.

---

## Verification status (as of last check)
```
flutter analyze   → clean (2 pre-existing deprecations in admin_portal_page.dart, unrelated to this work)
flutter test      → 65/65 passing
flutter build web --release → succeeds
```

## Known open item
I have not been able to visually verify any of this — the Browser pane isn't rendering screenshots in this environment. Everything above is verified structurally (analyzer/tests/build) but **not seen**. Please keep sending screenshots when something looks wrong; that's the only way I catch it.
