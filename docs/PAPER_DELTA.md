# PAPER_DELTA — Appstone

**Purpose.** This file tracks every difference between the running system and the capstone paper (`NEW APPSTONE.docx`), so the document can be revised section by section without re-reading any code.

**How to use it.** Open the paper beside Section 1 and work top to bottom. Sections 2–4 tell you what to *add* to the paper. Section 5 tells you what you can state confidently because it did **not** change. Section 6 is the screenshot checklist.

**Rule.** A phase of frontend work is not finished until its entries are written here.

| | |
|---|---|
| Paper revision | `NEW APPSTONE.docx` (revision pending — system refinement first) |
| Overhaul started | 2026-08-17 |
| Status | Phase 0 complete · Phases 1–5 pending |

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
| §4.4.1 (Colors) | Blue **#2563EB** is the main color; module colors green #22C55E, orange #F97316, purple #9333EA, red #EF4444, cyan #06B6D4, indigo #4F46E5, teal #0D9488 | Maroon **#8B1A1A** is the brand color (matches the Appstone logo, launcher icons, favicon, adaptive icon background and PWA theme color). Module accents are a new maroon-compatible set | **Rewrite the whole colour paragraph. Replace the colour swatch figures.** See Section 1a below for the exact palette to document | ⬜ |
| §4.4.1 (Colors) | Swatch figures list #FF0000, #808080, #FFFFFF, #000000 | Those four swatches do not correspond to anything in the system | Replace the swatch block entirely | ⬜ |
| §4.4.1 (Fonts) | Font stack "Segoe UI, Roboto, Helvetica Neue, Arial, sans-serif", base 16 px, two weights (400 normal, 500 medium) | **Plus Jakarta Sans**, bundled as an app asset (no runtime download), with a 10-step type scale and weights 400–800 | Rewrite the typography paragraphs | ⬜ |
| §4.4.1 (Fonts) | Figures 19–21 are Segoe UI / Helvetica Neue / Roboto specimens; Figures 21–22 are Arial / Sans Serif | Only one family is used | **Replace Figures 19–22 with a single Plus Jakarta Sans specimen + the type scale table** | ⬜ |
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

To be filled in with final hex values at the end of Phase 1.

| Role | Token | Hex | Used for |
|---|---|---|---|
| Brand | `brand` | `#8B1A1A` | App chrome, headers, primary buttons, focus states |
| Brand (dark) | `brandDark` | `#6B1414` | Pressed states, gradient depth |
| Premium | `premium` | `#8B7020` | Premium badges and locks |
| Danger | `danger` | `#C62828` | Destructive actions, time's-up |
| Module — Capstone Manual | `moduleManual` | *TBD* | Manual cards and accents |
| Module — Title Generator | `moduleTitleGen` | *TBD* | Title generator cards and accents |
| Module — Defense Practice | `moduleDefense` | *TBD* | Defense cards and accents |
| Module — AI Workflow | `moduleWorkflow` | *TBD* | Workflow cards and accents |
| Module — Paper Checker | `modulePaper` | *TBD* | Paper checker cards and accents |

---

## Section 2 — New features (not in the paper at all)

Each of these needs a new entry in the paper's scope section (§1.4.1) and probably a screenshot.

| # | Feature | What it does | Why | Lives in | Suggested doc § | Status |
|---|---|---|---|---|---|---|
| N1 | Dark mode + theme toggle | Full light/dark theme, user-toggleable, persisted per device (`theme_mode_v1`) | Students work at night; reduces eye strain and looks current | `lib/theme/` | New §4.4.1 subsection | ⬜ |
| N2 | Adaptive navigation shell | Bottom navigation on phones, navigation rail on tablet/desktop. Destinations: Home, Practice, Progress, Manual | The app previously had no persistent navigation at all — every screen was reached from the dashboard and exited with Back | `lib/widgets/app_shell.dart` | New §4.4.1 subsection | ⬜ |
| N3 | Home progress band | Live status strip: workflow deadline countdown + phases done, latest paper-check score with delta, last practice session score | The dashboard showed no state; students had no sense of progress | `lib/screens/dashboard_screen.dart` | §B (Student Dashboard) | ⬜ |
| N4 | Continue where you left off | One card deep-linking to the student's most recent activity | Reduces friction returning to the app | `lib/screens/dashboard_screen.dart` | §B | ⬜ |
| N5 | AI Workflow home preview | Mini timeline of the current plan rendered on Home from `WorkflowPlan.schedule()` | Makes the deadline visible without opening the module | `lib/screens/dashboard_screen.dart` | §B.4 | ⬜ |
| N6 | Continue where you left off | One card on Home deep-linking to the student's most recent activity | Reduces friction returning to the app; only links to screens that already exist | `lib/screens/dashboard_screen.dart` | §B | ⬜ |
| N7 | Premium upsell screen | A designed screen explaining what premium unlocks and how to get it | The paywall was a grey snackbar reading "Avail premium to access this feature." Same trigger, same permission logic — a restyle of an existing state | `lib/widgets/auth_guard.dart` | §A.3/§A.4 | ⬜ |
| N8 | Defense results charts | Animated score dial + radar chart over the four metrics the AI already returns | §B.3.7 already promises a "Performance Breakdown Dashboard" — this delivers what the paper claims | `lib/screens/defense_results_screen.dart` | §B.3.7 (existing) | ⬜ |
| N9 | Admin search | Filter groups and students by name, email, or student ID | The admin portal had no search at all | `lib/screens/admin_portal_page.dart` | §A | ⬜ |
| N10 | Skeleton loading + friendly errors | Shimmer placeholders while loading; plain-English error messages with a Try Again button | Previously 19 bare spinners and raw exception strings shown to users | `lib/widgets/states/` | §4.4.1 or testing section | ⬜ |
| N11 | Branded web loading splash | Maroon splash with the Appstone mark while the ~26 MB web build boots | The browser previously showed a blank white page for several seconds | `web/index.html` | §1.4.2.J | ⬜ |

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
| C1 | Tapping a locked premium feature showed a grey snackbar | Opens a designed upsell sheet explaining premium | ⬜ |
| C2 | Errors surfaced as raw `error.toString()`, including Firebase exception text | Plain-English messages with a **Try Again** action | ⬜ |
| C3 | Session History and Paper Check History were two separate destinations reached from two different screens | Both reached through one **Progress** destination via a segmented control (both screens still exist as separate files) | ⬜ |
| C4 | Admin student lists were a 6-column table that scrolled sideways on phones | Below 600 px they render as stacked cards | ⬜ |
| C5 | Every screen was a 760 px column centred on any monitor | Screens with a natural split use a two-column desktop layout above ~1100 px | ⬜ |
| C6 | Defense results were a text score with plain progress bars | Animated score dial, radar chart, staggered reveals, rank badge | ⬜ |
| C7 | No navigation persisted between screens | Persistent shell with four destinations | ⬜ |
| C8 | Single hardcoded light theme | Light + dark, user-toggleable | ⬜ |

---

## Section 4 — Fixed defects

Useful evidence for the paper's testing / QA discussion.

| # | File | Defect | Status |
|---|---|---|---|
| D1 | `web/index.html` | **No `<meta name="viewport">` tag** — mobile browsers rendered the app at desktop width and scaled it down, defeating all responsive layout on mobile web | ⬜ |
| D2 | `print_options_dialog.dart:97` | `SizedBox(width: 420)` inside an `AlertDialog` overflows on any device narrower than ~500 px (i.e. every phone) | ⬜ |
| D3 | 6 dialog sites | Multi-field dialog contents were not scrollable — overflowed whenever the keyboard opened | ⬜ |
| D4 | `ai_workflow_screen.dart:288` | Status `Row` with four unconstrained children and no `Flexible` — overflows on narrow screens or raised text scale | ⬜ |
| D5 | `icon_tile.dart:66` | `AppFeatureCard` had a fixed `height: 272` wrapped around unbounded text — overflows above ~1.4× text scale or when the card is narrow | ⬜ |
| D6 | `import_students_page.dart:174` | Button `Row` with no `Wrap` — overflows in the narrow admin drawer layout | ⬜ |
| D7 | `audit_log_page.dart:126`, `session_history_screen.dart:319` | `Row(mainAxisSize.min)` containing an unbounded `Text` placed inside a `Wrap` — long emails overflow with no ellipsis | ⬜ |
| D8 | `title_generator_screen.dart:541` | Hand-rolled chip wrap cannot break a chip wider than the available width — clips at large text scale on narrow screens | ⬜ |
| D9 | `auth_guard.dart:109` | `_PremiumRequired` is not scrollable — overflows on a short landscape phone | ⬜ |
| D10 | `admin_management_page.dart`, `audit_log_page.dart`, `import_students_page.dart` | No content max-width cap — stretch edge-to-edge on a wide monitor | ⬜ |
| D11 | `section_header.dart:36` | Long student name at `fontSize: 26` with no `maxLines`/ellipsis | ⬜ |
| D12 | `auth_guard.dart:51` | `_isPremiumStudent` has no `catch`, so a Firestore/network error is indistinguishable from "not premium" | ⬜ |
| D13 | `defense_results_screen.dart:43` | `maxWidth: 680` where every other student screen uses `760` | ⬜ |
| D14 | `web/manifest.json` | `orientation: "portrait-primary"` locks tablets and installed desktop PWAs to portrait | ⬜ |
| D15 | `pubspec.yaml`, `web/manifest.json`, `web/index.html` | All three still describe the app as "A new Flutter project." | ⬜ |
| D16 | `web/index.html:50` | PWA install button is `#9E1B1F`, which is not the brand colour `#8B1A1A` | ⬜ |

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
