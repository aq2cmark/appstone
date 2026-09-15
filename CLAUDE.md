# CLAUDE.md — Appstone

Guidance for Claude Code (and any future contributor) working in this repository.

---

## 1. What this project is

**Appstone** — *A Web and Mobile Application for Capstone Guidance.*
A Flutter, web-first Progressive Web App built for the **College of Computer Studies, Dominican College of Tarlac, Inc. (DCT)**. It turns the CCS Capstone Manual into an interactive system: a searchable manual, an AI title generator, gamified defense practice, an AI workflow planner, and an AI manuscript checker.

It is a **capstone project** (BSIT). The accompanying paper is `NEW APPSTONE.docx`. When the code and the paper disagree, record it in `docs/PAPER_DELTA.md` — do not silently change either one.

- **Frontend:** Flutter (Dart SDK `^3.8.1`), Material 3
- **Backend:** Firebase project `appstone-db`, region **`asia-east2`** (Firestore, Auth, Cloud Functions)
- **Deployment:** static `build/web` on Hostinger shared hosting (see `HOSTINGER_DEPLOY.md`). Firebase Hosting is *not* used. `vercel.json` + `api/nararouter.js` are dead Vercel leftovers.
- **Mobile story:** installed PWA (Android `beforeinstallprompt`, iOS Add to Home Screen). Native store builds are **not** release-ready — bundle IDs are still `com.example.appstone` and Android release signs with debug keys.

---

## 2. Commands

```bash
flutter analyze
```

```bash
flutter test
```

```bash
flutter run -d chrome
```

```bash
flutter build web --release
```

Regenerate launcher icons and the web favicon from the Appstone mark:

```bash
dart run flutter_launcher_icons
```

---

## 3. Architecture

```
lib/
  main.dart              MaterialApp, themes, named route table (all routes guarded)
  theme/                 design tokens — colors, type, spacing, breakpoints, motion, ThemeData
  models/                workflow_plan.dart — the only real domain model
  screens/               one file per screen; some files hold several related screens
  services/              all Firebase / HTTP / parsing logic; screens never touch Firebase directly
  widgets/               shared UI: shell, scaffold, state views, charts, logo, guards
```

**Data flow:** `screens/` → `services/` → Firebase. Screens must not import `cloud_firestore` or `firebase_auth` for data access; go through a service. (`FirebaseAuth.instance` for the *current user identity* is the one accepted exception, already used in the guards and the password-change flow.)

**State management:** deliberately none. There is no provider/riverpod/bloc.
- `StatefulWidget` + `setState` for screen state
- `StreamBuilder` over Firestore for live admin surfaces
- `SharedPreferences` as the de-facto app-wide store (`studentId`, `groupId`, `workflow_plan_v1`, `defense_context_v1`, `theme_mode_v1`, login prefs)
- **`PaperCheckController.instance`** (`services/paper_check_controller.dart`) is the *only* global object — a `ChangeNotifier` singleton that exists so a running paper check survives navigation. Do not add a second global; if you need one, ask first.

**Roles.** Two role strings live in `admins/{email}.role`: `owner` and `admin`. Students are not in `admins` at all — a user is a student if `studentIndex/{uid}` exists. There are **no Firebase custom claims**; role is a Firestore read on every sign-in. `adviser` and `panelist` appear only as manual *content* and in AI prompts — they are not system roles.

| Actor | Can reach |
|---|---|
| owner | everything an admin can, plus Admins page, Audit Log, ownership transfer |
| admin | groups CRUD, register/import/edit/delete students, grant premium, print credentials |
| student (free) | Capstone Manual, Title Generator |
| student (premium) | all five modules |

Route protection lives in `widgets/auth_guard.dart`: `AuthGuard` (signed in) and `PremiumGuard` (signed in **and** their group `isPremium`). This matters because Flutter web URLs are typeable — `/#/paper-checker` must not open for a free student.

---

## 4. Design system rules

These exist because the pre-overhaul codebase had ~147 inline `TextStyle`s, 26 font sizes, ~201 magic-number `SizedBox`es, and 36% of colors bypassing the palette. **Follow them or the app drifts back.**

**Color.** Use semantic tokens from `theme/app_colors.dart`.
- Never write `Colors.white`, `Colors.black`, `Colors.green`, `Colors.orange`, `Colors.red`, or a raw `Color(0xFF…)` in a screen.
- Use `AppColors.of(context)` so the token resolves for the current brightness. Hardcoded light colors break dark mode.
- Success / warning / danger / info are tokens, not `Colors.green.shade700`.
- Each module has an accent (`AppColors.moduleManual`, `moduleTitleGen`, `moduleDefense`, `moduleWorkflow`, `modulePaper`) plus a `tint` variant for soft backgrounds.

**Type.** Use the theme's `textTheme` or the named styles in `theme/app_typography.dart`. Never write an inline `TextStyle(fontSize: …)`. If a style is missing from the scale, add it to the scale rather than inlining one.

**Spacing, radius, elevation.** Use `AppSpacing`, `AppRadius`, `AppElevation`. No bare numbers in `SizedBox`, `EdgeInsets`, or `BorderRadius`.

**Page chassis.** Every screen uses `widgets/app_scaffold.dart`. Do not hand-build an `AppBar` or repeat the old `ListView > Center > ConstrainedBox(760)` idiom.

**Async surfaces.** Every loading / error / empty state uses `widgets/states/` — `AppLoading`, `SkeletonList`/`SkeletonCard`, `AppErrorView` (message + **Try Again**), `AppEmptyView`.
- **Never show a raw `error.toString()` to a user.** Route it through the friendly-message mapper. Firebase exception text is not user-facing copy.

**Dialogs.** Use `widgets/app_dialog.dart`, never a bare `AlertDialog`. Its content is scrollable — this is what stops multi-field dialogs from overflowing when the keyboard opens.

---

## 5. Responsive contract

Breakpoints live in `theme/app_breakpoints.dart` and are the **only** width thresholds allowed:

| Name | Width | Navigation |
|---|---|---|
| `compact` | `< 600` | `NavigationBar` (bottom) |
| `medium` | `600–1023` | `NavigationRail` (icons) |
| `expanded` | `1024–1439` | `NavigationRail` (icons) |
| `large` | `≥ 1440` | `NavigationRail` (extended) |

Rules:
- **No widget may set a fixed height around text.** Text wraps, and users change text scale. Use minimum heights and let content grow.
- Every `Text` that can receive user or AI data needs `maxLines` + `overflow`.
- Every `Row` with more than two children needs `Flexible`/`Expanded`, or must be a `Wrap`.
- Any `AlertDialog`/dialog content must be scrollable (use `AppDialog`).
- `DataTable` is desktop-only. Below `compact`, render stacked cards.
- Test every screen at **320, 360, 414, 768, 1024, 1440, 1920** px, portrait and landscape, at **1.0× and 2.0× text scale**.

---

## 6. Motion contract

Durations and curves come from `theme/app_motion.dart`. Two registers:

- **Calm (default, everywhere).** Entrance staggers, shared-axis page transitions, animated counters, hover/press feedback. Nothing bounces. `AppMotion.quick`/`standard` with `AppMotion.enter`.
- **Expressive (Defense Practice and Defense Results only).** Timer ring pulse, score dial sweep, radar reveal, one celebratory beat on a strong score. This is the "gamified" register the paper promises — it must not leak into the manual, the admin portal, or forms.

Reference implementations already in the codebase and worth matching: the dashboard hover-dock (`AnimatedScale`, 160ms `easeOut`) and the title generator's `_AnimatedChipWrap` (`AnimatedPositioned`, 260ms `easeOutCubic`).

Motion must never block input or delay a user's ability to act.

---

## 7. Hard constraints — do not break these

- **Never change Firestore collection or document shapes.** `groups` (with the embedded `students[]` array), `studentIndex/{uid}`, `studentIdToEmail/{STUxxx}`, `admins/{email}`, `practice_sessions`, `paper_checks`, `audit_logs`, `aiUsage/{uid}`, `metadata/studentCounter`.
- **Never touch the AI quota logic** in `functions/index.js` (`DAILY_AI_LIMIT`, session reservation, refunds, the Groq us-central1 relay). A defense practice run must stay **one** session across all its follow-up evaluations, transcriptions, and final scoring — that is why `DefenseAiService` mints one `sessionId` per instance and passes it to `SpeechTranscriptionService`.
- **Every route in `main.dart` stays wrapped** in `AuthGuard` or `PremiumGuard`.
- **The manuscript rubric totals exactly 50 points** (`services/paper_checker_service.dart`). A test enforces this. The Capstone Manual screen renders the same rubric from the same source — they must not diverge.
- **`firestore.rules` is out of scope** for frontend work.
- **`_AnimatedChipWrap` in `title_generator_screen.dart` measures chip widths with a `TextPainter`.** `_chipLabelStyle` must remain the single style used by both the measurement and the rendered chip, or chips silently overflow. Four widget tests guard this.
- **Preserve `PaperCheckController` behavior** — a check in flight must survive leaving and returning to the screen.
- Audit logging is append-only and best-effort; do not make it throw.

---

## 8. Tests

Nine files in `test/`, all pure unit/widget — no Firebase emulator, no network. They must stay green.

Fragile with respect to UI changes:
- `title_generator_screen_test.dart` — drives real chip reorders at several surface sizes; **an overflow fails the build.**
- `ai_workflow_deadline_test.dart` — asserts the deadline **date picker** flow and its `initialDate >= firstDate` behavior.
- `ai_workflow_tips_test.dart` — asserts tips reveal **inline with no loading**, and that a phase without tips is a plain non-expandable card.

Safe (pure logic): `workflow_plan_test.dart`, `docx_layout_checker_test.dart`, `paper_review_test.dart`, `student_import_service_test.dart`, `defense_context_test.dart`, `ai_endpoint_test.dart`.

---

## 9. Tracking changes for the paper

`docs/PAPER_DELTA.md` is a **required deliverable**, not a nice-to-have. Every phase of work ends by updating it. It exists so the capstone document can be revised section by section without re-reading code.

If you add a feature, change a behavior, or fix a defect that a reader of the paper would notice — write it down there before considering the work done.

---

## 10. Scope rule for the current overhaul

The capstone paper's use case, sequence, and activity diagrams are already drawn. Work in this repository is therefore limited to **UI, layout, responsiveness, theming, motion, loading/error/empty states, and defect fixes.**

**Do not add new user-facing capabilities.** Nothing that changes what the system *can do* — only how it looks and feels doing it. Re-presenting data the system already produces is fine; adding a new input, output, persisted value, or cross-module data flow is not.

Three proposals were explicitly cut under this rule and should not be reintroduced: PDF export of results, a Title Generator → Project Context / AI Workflow handoff, and Capstone Manual bookmarks. See `docs/PAPER_DELTA.md` § "Explicitly cut from scope".

---

## 11. Known issues flagged but out of scope

These are real and worth fixing, but they are backend/security, not frontend:

- `firestore.rules` lets **any signed-in user read every student's** `practice_sessions` and `paper_checks` (`read: if request.auth != null`, no ownership predicate).
- `admins` allows `list` to any signed-in user, so a student can enumerate the admin roster.
- The `firestore.rules` header comment is stale — it describes the pre-Auth-migration world.
- Dead code: `AdminRepository.inviteAdmin`, `AdminRepository.requestOwnershipTransfer`, `AdminRepository.authStateChanges` (all superseded by Cloud Function equivalents).
- `admin_management_page.dart` tells owners to use an "Invited as an admin? Create your account" screen that no longer exists.
- `StudentAccount.password` is a migration remnant that nothing populates.
