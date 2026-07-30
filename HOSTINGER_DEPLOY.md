# Uploading Appstone to Hostinger

Appstone is a Flutter web app with its backend on **Firebase**, not on the web
host. Hostinger only ever serves static files (`build/web`); every AI call, login
and database read still goes to Firebase. That is why moving hosts is a short
checklist rather than a migration.

| Piece | Where it lives after the move |
| --- | --- |
| The app itself (HTML/JS/assets) | Hostinger `public_html` |
| AI proxy (NaraRouter, Whisper, Groq relay) | Firebase Cloud Functions, `asia-east2` |
| Login, students, groups, history | Firebase Auth + Firestore |

Nothing in `functions/` needs redeploying to change hosts, and the endpoint the
app calls is a fixed Firebase URL (see `lib/services/ai_endpoint.dart`), so it
does not care which domain serves the page.

`vercel.json` and `api/nararouter.js` are for the old Vercel deployment only.
Hostinger cannot run them (shared hosting has no Node runtime) and the app no
longer uses them. Leave them or delete them - they change nothing here.

---

## 1. Build the release

From the project root:

```bash
flutter build web --release
```

If the app will live in a **subfolder** (`yourdomain.com/appstone/`) instead of
the domain root, the base href must match or every asset 404s:

```bash
flutter build web --release --base-href /appstone/
```

The finished site is everything inside `build/web` (about 26 MB).

## 2. Upload

Upload **the contents of `build/web`**, not the `build/web` folder itself, into
`public_html` (or `public_html/appstone/` for a subfolder).

- hPanel -> File Manager, or any FTP client.
- **`web/.htaccess` is included in the build output and must be uploaded.** It is
  a hidden file: in File Manager turn on "Show hidden files", and in FileZilla
  enable "Force showing hidden files". Easiest route: zip `build/web`, upload the
  zip, extract it in place, delete the zip.
- If a default Hostinger `index.php` or `default.php` is sitting in
  `public_html`, delete it - otherwise it may be served instead of `index.html`.

What the uploaded `.htaccess` does for you: forces HTTPS, sends unknown paths to
`index.html`, adds the `application/wasm` MIME type (a missing one shows up as a
blank white page), enables gzip on the multi-megabyte `main.dart.js`, and stops
browsers from caching stale code after a re-upload. For a subfolder install,
uncomment the `RewriteBase` line inside it.

## 3. Turn on SSL

hPanel -> Websites -> Security -> SSL, install the free certificate and wait for
it to go active.

This is not optional: **voice answers need a secure origin.** Browsers refuse
microphone access over plain `http://`, and Firebase Auth requires HTTPS too. The
`.htaccess` already redirects `http` to `https` once the certificate exists.

## 4. Authorize the new domain in Firebase

This is the step that breaks logins if it is missed.

Firebase Console -> project `appstone-db` -> **Authentication** -> **Settings**
-> **Authorized domains** -> **Add domain**, and add:

- `yourdomain.com`
- `www.yourdomain.com` (if you serve www as well)

Without this, sign-in fails on the new host with an "unauthorized domain" error,
and the owner-transfer / password-reset email links refuse to open. The app builds
those links from whatever domain it is served on (`Uri.base.origin`), so no code
change is needed - only the console entry.

## 5. Nothing to change for CORS or Firestore

The `nararouter` Cloud Function is deployed with `cors: true`, so it accepts the
new origin as-is, and it still requires a signed-in Firebase user - the domain is
not what protects it. `firestore.rules` are domain-independent.

## 6. Check it end to end

Open the site and confirm, in this order:

1. The page loads (not a white screen). A white screen is almost always a MIME or
   base-href problem - open DevTools -> Console.
2. A student can log in.
3. Refresh while on a feature page - the app should come back, not a 404.
4. Defense Practice -> **Add More Context** -> save, then start a session and
   submit one answer: this exercises Firestore *and* the AI proxy. A CORS or 403
   error in the Console means step 4 above was missed.
5. Tap **Answer with Voice** - the browser should ask for microphone permission
   (proves HTTPS is live).
6. On a phone, the Install button should appear (the PWA manifest is served).

## 7. Later updates

```bash
flutter build web --release
```

then re-upload the contents of `build/web` over the old files. Students on the
installed PWA pick up the new version on their next load because the service
worker revalidates `version.json`; if a stale page is ever suspected, a hard
refresh (Ctrl+Shift+R) settles it.

## Notes

- Hostinger and Vercel can both stay live pointing at the same Firebase project.
  Add both domains to Authorized domains if you keep both.
- The AI daily limits are per Firebase user, counted server-side, so they carry
  over unchanged to the new domain.
- Project context from "Add More Context" is stored per device
  (`shared_preferences`, i.e. browser local storage), not in Firestore - a
  student who switches browsers re-enters it. Moving hosts does not clear it, but
  changing domain does, because local storage is per-origin.
