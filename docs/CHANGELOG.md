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

## Queued animation/polish work (your picks, not yet built)
- ⬜ Staggered entrance on Manual/Workflow/History/Admin screens
- ⬜ Animated counters everywhere (scores, admin stat cards)
- ⬜ Progress bars/rings sweep to value instead of snapping
- ⬜ Skeleton → content crossfade
- ⬜ Scroll-linked app bar elevation
- ⬜ Hero transition from Home cards into module headers
- ⬜ Press feedback on cards/buttons (`AnimatedPressable` exists, needs wiring)
- ⬜ Empty-state gentle motion
- ⬜ Branded pull-to-refresh
- ⬜ Contrast/AA audit
- ⬜ Desktop density pass

---

## Verification status (as of last check)
```
flutter analyze   → clean (2 pre-existing deprecations in admin_portal_page.dart, unrelated to this work)
flutter test      → 65/65 passing
flutter build web --release → succeeds
```

## Known open item
I have not been able to visually verify any of this — the Browser pane isn't rendering screenshots in this environment. Everything above is verified structurally (analyzer/tests/build) but **not seen**. Please keep sending screenshots when something looks wrong; that's the only way I catch it.
