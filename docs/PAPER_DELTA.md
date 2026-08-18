# PAPER_DELTA — Appstone

**Purpose.** This file tracks every difference between the running system and the capstone paper (`NEW APPSTONE.docx`), so the document can be revised section by section without re-reading any code.

**How to use it.** Open the paper beside Section 1 and work top to bottom. Sections 2–4 tell you what to *add* to the paper. Section 5 tells you what you can state confidently because it did **not** change. Section 6 is the screenshot checklist.

**Rule.** A phase of frontend work is not finished until its entries are written here.

| | |
|---|---|
| Paper revision | `NEW APPSTONE.docx` (revision pending — system refinement first) |
| Overhaul started | 2026-08-17 |
| Status | Phases 0–2 complete · Phase 3: 7 screens rebuilt + dark mode correct on all 22 screens · Phases 4–5 pending |
| Verification | `flutter analyze` clean (2 pre-existing deprecations in `admin_portal_page.dart`) · all 65 tests passing · `flutter build web --release` succeeds |

---

## Legend

| Mark | Meaning |
|---|---|
| ✅ | Shipped in the system; paper still needs updating |
| 🔄 | In progress |
| ⬜ | Planned, not yet built |
| 📄 | Paper is wrong / outdated — correct the paper, not the code |

---

## Section 1 — Revision checklist

Ordered by document section. This is the part you work from.

| Doc § | Paper currently says | System now does | Action needed | Status |
|---|---|---|---|---|
| §1.3.2 / §1.4.1 | Lists 7 modules (auth, admin, manual, title generator, defense practice ×3, workflow, paper checker) | Same 7 modules, unchanged in scope | None — scope statement is still accurate | ✅ |
| §1.4.2.I (Mobile Hardware Limitations) | Android 10+, iOS 14+ | Accurate for the installed PWA. Native store builds are *not* release-ready (bundle IDs still `com.example.appstone`, Android release signs with debug keys) | Consider stating explicitly that distribution is via PWA install, not app stores | ⬜ |
| §1.4.2.J (Web Software Limitations) | "Performance may vary depending on device specifications and browser compatibility" | Can now be stated concretely: responsive from 320 px to 1920 px, four breakpoints, light + dark theme | Rewrite with the actual breakpoint table | ⬜ |
| §4.4.1 (Colors) | Blue **#2563EB** is the main color; module colors green #22C55E, orange #F97316, purple #9333EA, red #EF4444, cyan #06B6D4, indigo #4F46E5, teal #0D9488 | Maroon **#8B1A1A** is the brand color (matches the Appstone logo, launcher icons, favicon, adaptive icon background and PWA theme color). Module accents are a new maroon-compatible set | **Rewrite the whole colour paragraph. Replace the colour swatch figures.** See Section 1a below for the exact palette to document | ✅ shipped, Phase 1 |
| §4.4.1 (Colors) | Swatch figures list #FF0000, #808080, #FFFFFF, #000000 | Those four swatches do not correspond to anything in the system | Replace the swatch block entirely | ✅ shipped, Phase 1 |
| §4.4.1 (Fonts) | Font stack "Segoe UI, Roboto, Helvetica Neue, Arial, sans-serif", base 16 px, two weights (400 normal, 500 medium) | **Plus Jakarta Sans**, bundled as an app asset (no runtime download), with a 13-step type scale and weights 400–800. The old stack is now the *fallback* | Rewrite the typography paragraphs — see Section 1b | ✅ shipped, Phase 1 |
| §4.4.1 (Fonts) | Figures 19–21 are Segoe UI / Helvetica Neue / Roboto specimens; Figures 21–22 are Arial / Sans Serif | Only one family is used | **Replace Figures 19–22 with a single Plus Jakarta Sans specimen + the type scale table** | ✅ shipped, Phase 1 |
| §4.4.1 (new) | *(nothing)* | Navigation architecture: adaptive shell — bottom navigation on phones, navigation rail on tablet/desktop | **Add a new subsection** | ⬜ |
| §4.4.1 (new) | *(nothing)* | Light and dark theme with a user-facing toggle, persisted per device | **Add a new subsection** | ⬜ |
| §B.3.7 (Performance Breakdown Dashboard) | Metrics listed as clarity, technical accuracy, **confidence**, completeness, presentation | The AI scores **clarity, technical, completeness, presentation** only. `defense_ai_service.dart` deliberately omits *confidence* — the model receives the student's typed/transcribed text, never audio, so it cannot honestly assess vocal confidence | 📄 **Correct the paper. Do not change the code.** Remove "confidence" or reword it as a limitation | ⬜ |
| §B.3.7 | "A visual performance snapshot is displayed after each session" | Now genuinely visual: animated score dial + radar chart across the four metrics + per-session rank badge | Strengthen the wording; new screenshot needed | ⬜ |
| §B.4 (AI Workflow Planner) | Inputs described as "number of months allocated" (B.4.1) and "project title input" (B.4.2) | The screen asks for a **deadline date** (min tomorrow, max +730 days) and takes the **uploaded paper**, not a typed title. Enforced by `ai_workflow_deadline_test.dart` | 📄 **Correct B.4.1 and B.4.2 to match the implementation** | ⬜ |
| §B.5.1 | "PDF, DOC, or DOCX format, maximum 10MB" | `.doc` is **explicitly rejected** with a "save as PDF or .docx" message (`document_text_extractor.dart`); `.txt` is accepted | 📄 **Correct the accepted-format list** | ⬜ |
| §B.5.4 | Rubric categories: Formatting Standard, Chapter Structure, Documentation Standards, Content Quality; example scores "27/30, 22/30" | Real rubric is the Capstone Manual §8.3 manuscript rubric totalling **50 points** across 8 sections: Initial Pages 4, Ch1 10, Ch2 8, Ch3 8, Ch4 10, Final Pages 3, Appendices 2, Mechanics 5 | 📄 **Correct B.5.4 with the real 8-section, 50-point rubric** | ⬜ |
| §B.5 (new) | *(nothing)* | `.docx` uploads also get a deterministic **Layout Compliance** check (10 rules from Manual §10.3: paper size, four margins incl. the 1.5″ binding margin, header/footer distance, gutter, 1.5 line spacing, Times New Roman, 11 pt) | **Add a subsection** — this is a real feature the paper omits entirely | ⬜ |
| §A.1–A.5 (Admin Dashboard) | Admin can register students, assign groups, classify free/premium, verify premium, issue credentials | All accurate. Additionally: bulk roster import (.xlsx/.csv), printable credential sheets, audit log, admin invitations, ownership transfer | **Add the missing admin capabilities** — the paper undersells the admin module significantly | ⬜ |

### Section 1a — Palette to document in §4.4.1

Final values. Source of truth is `lib/theme/app_colors.dart`. Light-theme hexes are given; the dark theme lightens accents so they stay legible on dark surfaces.

**Brand and status**

| Role | Token | Light hex | Used for |
|---|---|---|---|
| Brand | `brand` | `#8B1A1A` | App chrome, primary buttons, focus rings, active navigation |
| Brand strong | `brandStrong` | `#6B1414` | Pressed states, depth |
| Brand soft | `brandSoft` | `#F6EAEA` | Selected rows, navigation indicator |
| Premium | `premium` | `#9A7A16` | Premium badges and locks |
| Success | `success` | `#1B7F4B` | Passed checks, completed phases |
| Warning | `warning` | `#B26A00` | Behind schedule, needs attention |
| Danger | `danger` | `#C62828` | Destructive actions, time's-up |
| Info | `info` | `#1E5F8C` | Neutral notices |

**Module accents** — each module owns a hue so the dashboard reads at a glance

| Module | Token | Light hex |
|---|---|---|
| Capstone Manual | `moduleManual` | `#8B1A1A` |
| Title Generator | `moduleTitleGen` | `#AD6A0B` |
| Defense Practice | `moduleDefense` | `#9A2C4E` |
| AI Workflow | `moduleWorkflow` | `#3B4B9A` |
| Paper Checker | `modulePaper` | `#0F766E` |
| — Title Defense mode | `titleDefense` | `#B4530A` |
| — Oral Defense mode | `oralDefense` | `#6B3FA0` |
| — Final Defense mode | `finalDefense` | `#A62B20` |

**Neutrals** — warm-tinted rather than pure grey, so they sit with the maroon

| Role | Light | Dark |
|---|---|---|
| Background | `#F5F3F0` | `#141110` |
| Surface (cards) | `#FFFFFF` | `#1E1A19` |
| Border | `#E3DDD6` | `#3A3331` |
| Text primary | `#1A1614` | `#F5F1EE` |
| Text secondary | `#6B625C` | `#B3A9A3` |

### Section 1b — Typography to document in §4.4.1

Source of truth is `lib/theme/app_typography.dart`.

- **Family:** Plus Jakarta Sans, bundled at `assets/fonts/PlusJakartaSans-Variable.ttf`.
- **Delivery:** a single *variable* font file (172 KB) with a continuous weight axis from 200 to 800, rather than five separate static weight files. One asset instead of five matters in a ~26 MB web build. Weights are selected in code through `TextStyle.fontVariations`.
- **No runtime download.** The font ships inside the app bundle, so it renders correctly offline, on a slow campus connection, and deterministically inside widget tests.
- **Fallback stack:** Segoe UI, Roboto, Helvetica Neue, Arial, sans-serif — the stack the paper currently describes is now the *fallback*, which is worth saying explicitly in the revision.
- **Weights used:** 400 regular, 500 medium, 600 semibold, 700 bold, 800 extrabold (the paper currently claims only 400 and 500).
- **Scale:** 13 named steps replacing the 26 ad-hoc font sizes the old code used.

| Step | Size | Weight | Used for |
|---|---|---|---|
| displayLarge | 40 | 800 | Score dials, hero numbers |
| displayMedium | 32 | 700 | Large counters |
| headlineLarge | 26 | 700 | Page hero titles |
| headlineMedium | 22 | 700 | Major section titles |
| headlineSmall | 19 | 600 | App bar titles, dialog titles |
| titleLarge | 17 | 600 | Card titles |
| titleMedium | 15 | 600 | List leads, form labels |
| titleSmall | 13.5 | 600 | Dense titles |
| bodyLarge | 16 | 400 | Primary reading copy |
| bodyMedium | 14.5 | 400 | Default body |
| bodySmall | 13 | 400 | Captions, metadata |
| labelLarge | 15 | 600 | Buttons |
| labelMedium / labelSmall / eyebrow | 13 / 11.5 / 11.5 | 500 / 500 / 700 | Chips, tabs, uppercase section markers |

---

## Section 2 — New features (not in the paper at all)

Each of these needs a new entry in the paper's scope section (§1.4.1) and probably a screenshot.

| # | Feature | What it does | Why | Lives in | Suggested doc § | Status |
|---|---|---|---|---|---|---|
| N1 | Dark mode + theme toggle | Full light/dark theme, user-toggleable from the account bar, persisted per device (`theme_mode_v1`), defaulting to the OS setting | Students work at night; reduces eye strain and looks current | `lib/theme/`, `lib/widgets/app_shell.dart` | New §4.4.1 subsection | ✅ Phase 1–2 |
| N2 | Adaptive navigation shell | Bottom navigation on phones (<600), icon rail on tablet/laptop (600–1439), extended rail with labels on desktop (≥1440). Destinations: Home, Practice, Progress, Manual | The app previously had no persistent navigation at all — every screen was reached from the dashboard and exited with Back | `lib/widgets/app_shell.dart` | New §4.4.1 subsection | ✅ Phase 2 |
| N3 | Home progress band | Three live tiles: workflow deadline countdown with phase ring, latest paper-check score with delta vs previous, last practice score with session count | The dashboard showed no state; students had no sense of progress | `lib/screens/dashboard_screen.dart` | §B (Student Dashboard) | ✅ Phase 2 |
| N4 | AI Workflow home preview | Read-only timeline bar of the saved plan, segments proportional to scheduled days and coloured done / overdue / upcoming, built entirely from `WorkflowPlan.schedule()` | Makes the deadline visible without opening the module | `lib/screens/dashboard_screen.dart` | §B.4 | ✅ Phase 2 |
| N5 | Continue where you left off | One card on Home deep-linking to the student's most relevant next action | Reduces friction returning to the app; only links to screens that already exist | `lib/screens/dashboard_screen.dart` | §B | ✅ Phase 2 |
| N6 | Premium upsell screen | A designed screen naming the feature they tried to open, listing what premium contains, and explaining that the administrator arranges it | The paywall was a grey snackbar reading "Avail premium to access this feature." Same trigger, same permission logic — a restyle of an existing state | `lib/widgets/premium_upsell.dart` | §A.3/§A.4 | ✅ Phase 2 |
| N7 | Defense results charts | Animated score dial + radar chart over the four metrics the AI already returns | §B.3.7 already promises a "Performance Breakdown Dashboard" — this delivers what the paper claims | `lib/widgets/charts/`, `lib/screens/defense_results_screen.dart` | §B.3.7 (existing) | ✅ Phase 3 |
| N8 | Admin search | Filter groups and students by name, email, or student ID | The admin portal had no search at all | `lib/screens/admin_portal_page.dart` | §A | ⬜ Phase 4 |
| N9 | Skeleton loading + friendly errors | Shimmer placeholders while loading; plain-English error messages with a Try Again button | Previously 19 bare spinners and raw exception strings shown to users | `lib/widgets/states/`, `lib/services/friendly_error.dart` | §4.4.1 or testing section | 🔄 built Phase 1, rolled out Phases 3–4 |
| N10 | Branded web loading splash | Maroon splash with the Appstone mark while the web build boots | The browser previously showed a blank white page for several seconds | `web/index.html` | §1.4.2.J | ⬜ Phase 5 |
| N11 | Export results as PDF | "Export as PDF" on the Defense Results screen and the Paper Checker report, producing a branded A4 document with the score, metric bars, rubric breakdown, formatting table and a disclaimer | Students can save or hand a real document to their adviser. Uses the `pdf` + `printing` packages already in the project for the admin credential sheet, so no dependency was added, and it prints only data the screen already shows | `lib/services/report_printer.dart` | New subsection under §B.3.7 and §B.5 | ✅ Phase 3 |
| N12 | Split login layout | Branded panel + form side by side above 1024 px; compact lockup above the form on phones | The login screen was a 420 px column on every screen size. First impression of the system | `lib/screens/login_page.dart` | §4.4.1 (new) | ✅ Phase 3 |
| N13 | Live countdown ring | The defense timer is a ring that drains with the clock, shifts calm → warning → danger, and breathes in the last 30 seconds | §B.3.1 promises a timed question display "to feel the pressure"; a static text pill did not deliver that | `lib/screens/title_defense_screen.dart` | §B.3.1 (existing) | ✅ Phase 3 |

### Explicitly cut from scope

Decided 2026-08-17. These were proposed, considered, and **deliberately not built** because they would add genuinely new capabilities and therefore force revisions to the use case, sequence, and activity diagrams. Recorded here so the decision is not revisited by accident.

| Proposal | Why it was cut |
|---|---|
| Export Paper Checker / Defense Results as PDF | New user capability — would add an output step to the §B.5 and §B.3 activity and sequence diagrams |
| Title Generator → Project Context / AI Workflow handoff | New cross-module data flow — would change the §B.2, §B.3 and §B.4 sequence diagrams |
| Capstone Manual bookmarks + continue reading | New persisted user data and new interactions — would change the §B.1 activity diagram |

**Scope rule for the remainder of this work:** UI, layout, responsiveness, theming, motion, states, and defect fixes only. Nothing that changes what the system *can do* — only how it looks and feels doing it.

---

## Section 3 — Changed behavior

Things a user or panelist would notice behaving differently, even where the paper is silent.

| # | Before | After | Status |
|---|---|---|---|
| C1 | Tapping a locked premium feature showed a grey snackbar | Opens a designed upsell screen explaining premium | ✅ Phase 2 |
| C2 | Errors surfaced as raw `error.toString()`, including Firebase exception text | Plain-English messages with a **Try Again** action | 🔄 Phases 2–4 |
| C3 | Session History and Paper Check History were two separate destinations reached from two different screens | Both reached through one **Progress** destination (both screens still exist as separate files) | 🔄 Progress destination live Phase 2; segmented control Phase 3 |
| C4 | Admin student lists were a 6-column table that scrolled sideways on phones | Below 600 px they render as stacked cards | ⬜ Phase 4 |
| C5 | Every screen was a 760 px column centred on any monitor | Screens with a natural split use a two-column desktop layout above 1024 px | 🔄 Phase 3 — done on paper checker, defense session, defense results, login |
| C6 | Defense results were a text score with plain progress bars | Animated score dial, radar chart, staggered reveals, rank badge | ✅ Phase 3 |
| C7 | No navigation persisted between screens | Persistent shell with four destinations, adapting to window size | ✅ Phase 2 |
| C8 | Single hardcoded light theme | Light + dark, user-toggleable, persisted | ✅ Phase 2 |
| C9 | The student dashboard header was a solid maroon banner with the student's name and icon buttons | An app bar with the Appstone mark, an account menu (name, group, change password, log out) and the theme toggle; the greeting and group chips moved into the page body | ✅ Phase 2 |
| C10 | A floating "Install" button was pinned to the right edge of every web page, plus an iOS "Add to Home Screen" tip bubble | Removed at your request. Browsers still offer PWA installation through their own address-bar / share-sheet affordances; `manifest.json` is unchanged, so installability is unaffected | ✅ Phase 2 |
| C11 | Hovering a dashboard feature card magnified it and shrank its neighbours, but only when all five fitted on one row — and it required the fixed card height that caused defect D5 | Every card lifts, glows in its module colour and tints its border on hover, at every window width | ✅ Phase 2 |

---

## Section 4 — Fixed defects

Useful evidence for the paper's testing / QA discussion.

| # | File | Defect | Status |
|---|---|---|---|
| D1 | `web/index.html` | No `<meta name="viewport">` tag in the HTML. **Corrected after verification:** this is *not* the critical bug it first appeared to be — the Flutter engine injects `width=device-width, initial-scale=1.0, maximum-scale=5.0` at runtime during bootstrap (confirmed in `build/web/main.dart.js`), so the running app is laid out correctly on mobile. The real, smaller issue is that the meta only exists *after* `main.dart.js` boots, which on a ~26 MB build over campus wifi is several seconds. Until then mobile browsers use the default ~980 px layout viewport, which mis-scales the pre-boot content in `index.html` (the PWA install button, the iOS tip, and the branded splash being added in Phase 5). Fix is to declare it explicitly in the HTML so it applies from first paint. | ⬜ |
| D2 | `print_options_dialog.dart:97` | `SizedBox(width: 420)` inside an `AlertDialog` overflows on any device narrower than ~500 px (i.e. every phone) | ⬜ |
| D3 | 6 dialog sites | Multi-field dialog contents were not scrollable — overflowed whenever the keyboard opened | ⬜ |
| D4 | `ai_workflow_screen.dart:288` | Status `Row` with four unconstrained children and no `Flexible` — overflows on narrow screens or raised text scale | ⬜ |
| D5 | `icon_tile.dart:66` | `AppFeatureCard` had a fixed `height: 272` wrapped around unbounded text — overflows above ~1.4× text scale or when the card is narrow. Now sizes to content with a minimum height, and both text runs are bounded with `maxLines` + ellipsis | ✅ Phase 2 |
| D17 | `title_generator_screen.dart:52` | **Introduced and fixed during Phase 1.** `_chipLabelStyle` set no font family, so the `TextPainter` that measures chip widths resolved the platform default while the rendered chip inherited the theme family. Harmless while both were Roboto; once the app moved to Plus Jakarta Sans the two disagreed and chips would have overflowed their reserved width. The four widget tests would not have caught it because they run against the default theme. The family and weight are now pinned into the measured style | ✅ Phase 1 |
| D18 | 13 screens (`ai_workflow_screen.dart`, `capstone_manual_screen.dart`, `title_generator_screen.dart`, `session_history_screen.dart`, admin pages, …) | **Dark mode was unreadable on every screen not yet migrated.** Those screens hardcoded `Card(color: Colors.white)` and `Scaffold(backgroundColor: AppColors.background)` (a light constant), but their `Text` widgets carried no explicit colour — so text inherited the *dark* theme's light-on-dark colour and rendered light grey on a white card. Fixed by deleting the hardcoded surfaces so both inherit `cardTheme`/`scaffoldBackgroundColor`, which resolve per brightness; the 3 `AppColors.textDark` sites and the Title Generator chip labels were repointed at the theme's `colorScheme` | ✅ Phase 3 |
| D19 | All 13 previously-unmigrated screens | **Dark mode fixed properly.** Every screen was moved off the legacy const palette (`lib/app_colors.dart`) onto the brightness-aware `AppColors.of(context)`: 118 legacy colour references remapped, `Colors.green`/`Colors.orange` replaced with the `success`/`warning` tokens, the three hardcoded light tints (`0xFFECECEC`, `0xFFFDECEC`, `0xFFFFF8E7`) replaced with `surfaceSunken`/`dangerTint`/`warningTint`, and two `fillColor: Colors.white` text fields repointed at `surface`. `lib/app_colors.dart` was then **deleted**, so no screen can regress onto a fixed light colour. Layout, structure and copy on these screens were left untouched | ✅ Phase 3 |
| D6 | `import_students_page.dart:174` | Button `Row` with no `Wrap` — overflows in the narrow admin drawer layout | ⬜ |
| D7 | `audit_log_page.dart:126`, `session_history_screen.dart:319` | `Row(mainAxisSize.min)` containing an unbounded `Text` placed inside a `Wrap` — long emails overflow with no ellipsis | ⬜ |
| D8 | `title_generator_screen.dart:541` | Hand-rolled chip wrap cannot break a chip wider than the available width — clips at large text scale on narrow screens | ⬜ |
| D9 | `auth_guard.dart:109` | `_PremiumRequired` is not scrollable — overflows on a short landscape phone | ✅ Phase 3 — replaced by the scrollable premium upsell screen |
| D10 | `admin_management_page.dart`, `audit_log_page.dart`, `import_students_page.dart` | No content max-width cap — stretch edge-to-edge on a wide monitor | ⬜ |
| D11 | `section_header.dart:36` | Long student name at `fontSize: 26` with no `maxLines`/ellipsis | ⬜ |
| D12 | `auth_guard.dart:51` | `_isPremiumStudent` has no `catch`, so a Firestore/network error is indistinguishable from "not premium" | ✅ Phase 3 — a lookup failure now shows a retryable error, not a paywall |
| D13 | `defense_results_screen.dart:43` | `maxWidth: 680` where every other student screen uses `760` | ✅ Phase 3 — student screens now use the shared AppContentWidth scale |
| D14 | `web/manifest.json` | `orientation: "portrait-primary"` locks tablets and installed desktop PWAs to portrait | ⬜ Phase 5 |
| D15 | `pubspec.yaml`, `web/manifest.json`, `web/index.html` | All three still describe the app as "A new Flutter project." | 🔄 `pubspec.yaml` and `index.html` fixed Phase 1–2; `manifest.json` Phase 5 |
| D16 | `web/index.html:50` | PWA install button was `#9E1B1F`, not the brand `#8B1A1A` | ✅ moot — the install button was removed entirely (see C10) |

---

## Section 5 — Unchanged contracts

State these confidently in the paper and in defense. The frontend overhaul did **not** touch any of them.

- **Firestore collections and document shapes** — `groups` (with the embedded `students[]` array), `studentIndex/{uid}`, `studentIdToEmail/{STUxxx}`, `admins/{email}`, `practice_sessions`, `paper_checks`, `audit_logs`, `aiUsage/{uid}`, `metadata/studentCounter`.
- **`firestore.rules`** — the permission model is unchanged.
- **All Cloud Functions** — `nararouter`, `groqRelay`, `createStudent`, `resetStudentPassword`, `deleteStudent`, `sendPasswordResetEmail`, `inviteAdmin`, `requestOwnershipTransfer`, `finishStudentPasswordChange`. Signatures and behavior unchanged.
- **The AI quota model** — 5 sessions per user, per feature, per UTC day; server-side backoff and session refunds; one defense practice run counts as one session across all its evaluations, transcriptions, and final scoring.
- **AI providers and routing** — Mistral Large via NaraRouter for paper checker / workflow / defense; Groq (`openai/gpt-oss-20b`, `whisper-large-v3`) via the us-central1 relay for title generation and speech.
- **The 50-point manuscript rubric** — `services/paper_checker_service.dart`, enforced by `paper_review_test.dart`, and rendered from the same source in the Capstone Manual screen.
- **The `.docx` layout checker rules** — Capstone Manual §10.3, 10 deterministic rules, no AI.
- **The role model** — owner / admin / student, resolved by Firestore read, no custom claims.
- **The ownership transfer flow** — email-link proof to the current owner's own inbox, explicit confirmation, atomic two-document role swap.
- **The workflow scheduling algorithm** — weight-proportional day allocation with a 1-day floor and largest-remainder distribution (`models/workflow_plan.dart`).
- **All 9 test files** — still passing.

---

## Section 6 — Figures to recapture

Screenshots in the paper that are now outdated. Re-capture at the end, once all phases are done.

| Figure / location | Screen | How to reach it | Status |
|---|---|---|---|
| §4.4.1 colour swatches | n/a — replace with the new palette table | Section 1a above | ⬜ |
| Figures 19–22 (font specimens) | n/a — replace with one Plus Jakarta Sans specimen + type scale | Section 1a | ⬜ |
| Login screen | `LoginPage` | App start, signed out | ⬜ |
| Student dashboard | Home | Sign in as a student | ⬜ |
| Capstone Manual | `CapstoneManualScreen` | Home → Capstone Manual | ⬜ |
| Title Generator | `TitleGeneratorScreen` | Home → Title Generator | ⬜ |
| Defense Practice menu | `DefensePracticeScreen` | Home → Defense Practice (premium) | ⬜ |
| Defense session | `DefensePracticeSessionScreen` | Defense Practice → Title Defense | ⬜ |
| Defense results | `DefenseResultsScreen` | Finish a defense session | ⬜ |
| AI Workflow | `AIWorkflowScreen` | Home → AI Workflow (premium) | ⬜ |
| Paper Checker | `PaperCheckerScreen` | Home → Paper Checker (premium) | ⬜ |
| Admin dashboard | `AdminPortalPage` | Sign in as admin | ⬜ |
| Register student | `RegisterStudentForm` | Admin → Register Student | ⬜ |
| Import students | `ImportStudentsPage` | Admin → Import Students | ⬜ |
| Audit log | `AuditLogPage` | Sign in as owner → Audit Log | ⬜ |
| *(new)* Dark mode | any screen | Toggle theme in the shell | ⬜ |
| *(new)* Mobile layout | any screen | Resize to 360 px or install the PWA | ⬜ |
| *(new)* Layout compliance card | `PaperCheckerScreen` | Check a `.docx` manuscript | ⬜ |
