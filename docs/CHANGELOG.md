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

## Still queued
- ⬜ Scroll-linked app bar elevation
- ⬜ Hero transition from Home cards into module headers — *highest risk item; a tag mismatch throws at runtime rather than degrading quietly, so worth doing alone*
- ⬜ Skeleton → content crossfade
- ⬜ Full custom pull-to-refresh drawing the Appstone mark
- ⬜ Contrast/AA audit
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
