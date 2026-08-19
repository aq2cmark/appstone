# ENCRYPTION — Appstone

**Purpose.** A record of every cryptographic control in the system, where it comes from, and — just as important — the deliberate decision **not** to add more. Written because "shouldn't this be hashed?" is a predictable panel question and a predictable instinct for a future contributor. The answer is written down once, here, with the reasoning.

**Scope.** Firestore (`appstone-db`, `asia-east2`), Firebase Auth, and the Cloud Functions in `functions/index.js`.

**Rule for contributors.** Do not add hashing or encryption to a Firestore field without reading Section 5 first. Every field in this database is currently either (a) not a secret, or (b) protected by something stronger than a hash would be. Adding a hash to any of them makes the system worse, not better — Section 5 explains exactly how.

| | |
|---|---|
| Last reviewed | 2026-08-20 |
| Source of truth | `firestore.rules`, `functions/index.js`, `lib/services/admin_repository.dart` |
| Verified against | repo working tree — **deployed** rules must be confirmed in the Firebase Console |

---

## Section 1 — Summary

Appstone uses **four** cryptographic controls. Three are provided by the platform and require no code. One is our own, and it is not a security control.

| # | Control | Algorithm | Who provides it | Configurable |
|---|---|---|---|---|
| 1 | Encryption at rest | AES-256 | Google (automatic) | No |
| 2 | Encryption in transit | TLS 1.2+ | Google (automatic) | No |
| 3 | Password hashing | scrypt (modified) | Firebase Auth | No |
| 4 | Content fingerprinting | SHA-256 | Our code (`paper_check_controller.dart`) | n/a — not security |

**Nothing else in this system is encrypted or hashed, and nothing else should be.**

---

## Section 2 — Encryption at rest

Every document written to Firestore is encrypted with **AES-256** before it reaches disk. Google manages the key hierarchy: data is split into chunks, each chunk gets a data encryption key (DEK), and DEKs are wrapped by key encryption keys held in Google's internal KMS.

- Always on. Cannot be disabled.
- No cost, no configuration, no code.
- Applies to Firestore, Firebase Auth, and Cloud Functions storage alike.

**What it defends against:** physical compromise of Google datacenter media.

**What it does NOT defend against:** anything `firestore.rules` permits. Decryption is transparent to every authorized read — an over-permissive rule bypasses this layer entirely. **This is the single most misunderstood point about Firestore security and worth stating plainly in the paper.**

### Customer-Managed Encryption Keys (CMEK) — considered, rejected

Firestore supports CMEK, where the database is encrypted with a Cloud KMS key you own and can revoke. It was evaluated and **deliberately not adopted**:

| Reason | Detail |
|---|---|
| Cannot be retrofitted | CMEK is set **at database creation only**. `appstone-db` already exists; adopting it means creating a second database, migrating all 9 collections, and repointing the app |
| Wrong threat model | CMEK defends against Google itself. Appstone's threat model is other students and unauthorized web clients — CMEK addresses neither |
| Adds a failure mode | Disable or destroy the key by accident and the entire database becomes permanently unreadable |
| Adds cost | KMS key operations are billed per use |

**Verdict:** correct for a bank, wrong for a college capstone system. Document as a considered alternative; do not implement.

---

## Section 3 — Encryption in transit

All client-to-Firestore traffic is TLS-encrypted, on every platform Appstone runs on:

| Path | Transport |
|---|---|
| Flutter web (PWA) → Firestore | HTTPS / WebChannel |
| Flutter mobile → Firestore | gRPC over TLS |
| Client → Cloud Functions (`asia-east2`) | HTTPS |
| Cloud Functions → Groq relay (`us-central1`) | HTTPS |

Always on, no configuration. Hostinger serves `build/web` over HTTPS, so the PWA shell is protected in transit as well. Note that a PWA **requires** a secure context to install — the service worker will not register over plain HTTP, so this layer is load-bearing for the mobile story, not just for confidentiality.

---

## Section 4 — Password hashing (the only hashing that belongs here)

**Student and admin passwords are never stored by Appstone.** They live in Firebase Auth, which hashes them with an internally modified **scrypt** — a memory-hard function chosen specifically to resist GPU and ASIC brute-forcing.

Consequences worth knowing:

- No Appstone code, Firestore document, or Cloud Function ever sees a stored password.
- Password *verification* happens inside Firebase Auth. We call `signInWithEmailAndPassword` and receive a result.
- We could not read a user's password if we wanted to, including from the Firebase Console.

**The one field that looks like an exception:** `groups/{id}.students[].tempPassword` holds an admin-issued temporary password in plaintext. This is correct and intentional:

| Question | Answer |
|---|---|
| Why plaintext? | An admin must read it back to dictate it to a student and to run **Print Credentials** (`credentials_printer.dart`). A hash cannot be read back — hashing it breaks both shipped features |
| How long does it live? | Only until first use. `functions/index.js:882` writes `mustChangePassword: false, tempPassword: ''` the moment the student sets their own password |
| Is the real password ever there? | No. The temp password is set on the Firebase Auth account too; once changed, Auth holds the new one and the Firestore copy is cleared |
| Who can read it? | Active admins, and the owning student's own group (`isOwnGroup`) — enforced in `firestore.rules` |

This is the standard **bootstrap credential** pattern: short-lived plaintext, deleted on use. `StudentAccount.password` is a pre-Auth-migration remnant that nothing populates and should be deleted from the model.

---

## Section 5 — Why no additional hashing

This is the section to read before "hardening" anything.

### The principle

**Hashing is one-way. You hash a value you only ever need to *verify*, never *read back*.** A password qualifies: the system checks a guess against the hash and never needs the original. Almost nothing else in a normal application qualifies — and nothing else in Appstone does.

### Applied to `admins/{email}`

Every field must be read back to function. Hashing any of them breaks the feature that depends on it:

| Field | Read back for | If hashed |
|---|---|---|
| `email` | It **is** the document ID — `resolveAdminAccess()` looks up by it | Sign-in breaks entirely |
| `role` | Compared to `'owner'` / `'admin'` to authorize | Provides zero secrecy — see below |
| `uid` | Linked and compared on first sign-in | Auth linking breaks |
| `active` | Read as a boolean gate | Provides zero secrecy — see below |
| `name` | Rendered in the admin management page | Display breaks |

### The low-cardinality problem

`role` has exactly **two** possible values. `active` has **two**. Hash them and an attacker computes `sha256("owner")` and `sha256("admin")` once, compares, and recovers every value instantly. A rainbow table with two entries is not a meaningful obstacle.

**Hashing only provides confidentiality when the input space is too large to enumerate.** For an enum, a boolean, or a known email address, the input space is trivially small — the hash is decoration. This is why the instinct "sensitive-looking data should be hashed" is the wrong test. The right test is: *can the value be guessed and checked?* If yes, hashing it protects nothing.

`email` fails the same test for a second reason: it is the document ID, so hashing it destroys the lookup that sign-in depends on, **and** anyone guessing an address can hash it and confirm a hit.

### What protects this data instead

**Authorization, not transformation.** A hash you must reverse to use is not protection; a security rule that refuses to serve the document is. The data in `admins` is not secret in the cryptographic sense — it is *access-controlled*. See Section 7.

### Salting does not rescue it

A per-document salt defeats precomputed rainbow tables, but not targeted checking: the salt is stored beside the hash, so an attacker who can read the document reads the salt too and hashes the two candidate roles against it. Salting helps when an attacker has a *dump* and wants *bulk* recovery. It does not help when the value space is two.

---

## Section 6 — The one hash we do use, and why it is not security

`paper_check_controller.dart:161` computes a **SHA-256** fingerprint over the extracted manuscript text, the layout-rule signature, and a checker version prefix. It is stored on `paper_checks/{id}.contentHash` and used to recognise a **re-upload of identical content**, so the same manuscript is not graded twice and does not consume a second AI quota unit.

This is a **content fingerprint, not a security control.** It is worth being precise about the distinction in the paper:

| | Password hash | Content fingerprint |
|---|---|---|
| Purpose | Prevent recovery of the input | Detect that two inputs are identical |
| Wants to be slow | Yes (scrypt, memory-hard) | No — fast is better |
| Salted | Yes, per user | No — identical input **must** produce an identical digest, or dedupe fails |
| Reversibility matters | Yes | No — the original text is not secret from its own author |

The version prefix intentionally invalidates every fingerprint when the rubric changes, so a rubric revision re-grades rather than serving a stale score.

`functions/index.js` also uses `crypto.randomInt()` to generate temporary passwords (line 90). That is a **CSPRNG**, not a hash — the correct primitive for credential generation, and worth keeping as-is over `Math.random()`.

---

## Section 7 — What would actually improve security

None of the above. The real gap is authorization, in `firestore.rules`:

| Collection | Current rule | Problem |
|---|---|---|
| `admins` | `allow get, list: if request.auth != null` | Any signed-in user — **including any student** — can enumerate the full admin roster: emails, names, roles, uids |
| `practice_sessions` | `allow read: if request.auth != null` | Any signed-in user can read every student's defense practice history |
| `paper_checks` | `allow read: if request.auth != null` | Any signed-in user can read every student's manuscript check results |

The correct pattern **already exists in the same file**, on `studentIndex`, which restricts reads to an active admin or the owning uid, with a comment explaining why. The three collections above simply never received an ownership predicate.

For `admins` the fix is narrow, because the access pattern is already clean — `resolveAdminAccess()` only ever reads the caller's *own* document, and `adminsStream()` serves only the owner-only management page. A `get` restricted to own-email-or-active-admin, plus a `list` restricted to owners, covers every real call site.

**One fix here is worth more than every hash proposed in Section 5 combined**, because it addresses the layer that at-rest encryption explicitly cannot: an authorized-but-unauthorized read.

Status: **not yet applied.** Backend/security work, outside the UI-and-defects scope of the current overhaul (`CLAUDE.md` §10), and tracked as a known issue in `CLAUDE.md` §11.

---

## Section 8 — Data inventory

What each collection actually holds, and whether it contains a secret. Useful for the paper's security section and for answering "what happens if this leaks?"

| Collection | Contents | Secret? |
|---|---|---|
| `admins/{email}` | email, name, role, uid, active, timestamps | **No.** PII and role metadata. No credentials |
| `groups/{id}` | group name, isPremium, embedded `students[]` (id, name, email, uid, tempPassword, mustChangePassword) | **Transiently** — `tempPassword` until first login, then cleared |
| `studentIndex/{uid}` | groupId for one student | No |
| `studentIdToEmail/{STUxxx}` | email, uid — the student-ID → login lookup | No. Enables ID-based sign-in |
| `practice_sessions/{id}` | groupId, studentId, sessionType, questionsAnswered, durationSeconds, overallScore, createdAt | No — scores, not transcripts. **Answer text is never persisted** |
| `paper_checks/{id}` | groupId, studentId, fileName, scores, verdict, summary, sections, layout counts, contentHash | No — findings only. **Manuscript text is never persisted** |
| `aiUsage/{uid}` | daily AI quota counters | No |
| `audit_logs/{id}` | actor, action, description, timestamp | No — append-only admin action trail |
| `metadata/studentCounter` | the STUxxx sequence | No |

Two design decisions worth highlighting in the paper: **neither the student's spoken/typed defense answers nor the uploaded manuscript text is ever written to Firestore.** Both are processed in memory and only the derived scores are stored. That is a stronger privacy property than encrypting them would be — data that is never stored cannot leak, and it required no cryptography to achieve.

---

## Section 9 — Decision record

| Proposal | Decision | Reason |
|---|---|---|
| Rely on Firestore at-rest AES-256 | **Adopted** (automatic) | Free, mandatory, zero-maintenance |
| Rely on TLS in transit | **Adopted** (automatic) | Free, mandatory; also required for PWA install |
| Firebase Auth scrypt for passwords | **Adopted** (automatic) | Memory-hard, platform-maintained, no key handling on our side |
| SHA-256 content fingerprint for paper checks | **Adopted** | Dedupe + AI quota protection; explicitly not a security control |
| CMEK via Cloud KMS | **Rejected** | Cannot retrofit an existing database; wrong threat model; adds a catastrophic failure mode |
| Hash `role` / `active` / `email` / `uid` | **Rejected** | Breaks lookup and display; provides zero secrecy on a 2-value input space |
| Hash `tempPassword` | **Rejected** | Must be read back for credential handoff and Print Credentials; already cleared on first use |
| Application-layer AES-256-GCM on stored results | **Rejected — unnecessary** | The sensitive inputs (answer text, manuscript text) are never persisted; only derived scores are |
| Tighten `firestore.rules` ownership predicates | **Accepted, not yet applied** | The one change that closes a real gap. Out of scope for the UI overhaul; see `CLAUDE.md` §11 |
