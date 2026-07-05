# FreshCart / LB Super Market — Flutter + Firebase Grocery App

Production scaffold following Clean Architecture (data / domain / presentation
per feature), Riverpod for state management + DI, Go Router for navigation.

## What's included in this scaffold

- **Full folder structure** for every module planned (core/, all `features/*`
  folders including admin sub-sections), matching the locked architecture doc.
- **Fully coded Authentication module** — sign in, sign up, forgot password,
  phone OTP scaffolding, role resolution (customer / employee / admin) via
  Firestore lookup (`staff_users` collection), and a router with auth-based
  redirect guards (customers → `/home`, staff → `/admin/dashboard`).
- **Core infrastructure**: theme (light/dark, Material 3), error handling
  contract (`Failure` / `Result<T>` / `guard()`), Firestore path constants
  matching the final schema, Hive-based local cache bootstrap, Firebase
  bootstrap (`main.dart` + dev/staging/prod flavor entrypoints).
- **`firestore.rules`** and **`storage.rules`** — production security rules
  matching the confirmed 3-role model and full collection list.
- **`firestore.indexes.json`** — starter composite indexes for the queries
  Home/Orders will need first.

## What's stubbed (folders exist, code doesn't yet)

Every other feature (`home`, `categories`, `products`, `cart`, `checkout`,
`orders`, `wishlist`, `search`, `notifications`, `profile`, `order_requests`,
`support`, `business_info`, and all `admin/*` sub-modules) has its
`data/domain/presentation` folders created and ready, but no code inside yet.
We build these one at a time, same pattern as Authentication.

`home_screen.dart` and `admin_dashboard_screen.dart` are minimal placeholders
just so the router has somewhere to send you after login — replace these
when we get to those modules.

## Setup steps

1. **Install the FlutterFire CLI** (if you haven't already):
   ```
   dart pub global activate flutterfire_cli
   ```

2. **Connect this project to Firebase.** From the project root:
   ```
   flutterfire configure --project=lb-super-market
   ```
   This overwrites `lib/core/config/firebase_options.dart` with real values —
   the current file is a placeholder that intentionally throws if used as-is.

3. **Install dependencies:**
   ```
   flutter pub get
   ```

4. **Deploy security rules** (requires Firebase CLI: `npm install -g firebase-tools`, then `firebase login`):
   ```
   firebase deploy --only firestore:rules,storage:rules --project lb-super-market
   ```
   Point the CLI at `backend/firestore/firestore.rules` and
   `backend/security/storage.rules` via your `firebase.json` (create one
   with `firebase init` if you don't have it yet, pointing rules paths at
   the `backend/` locations above rather than the default root paths).

5. **Run it:**
   ```
   flutter run -t lib/main_dev.dart
   ```

6. **Sign up a test account**, then in Firestore, manually verify your
   `staff_users/{uid}` doc (created earlier in the console) has the exact
   same UID as your new Firebase Auth user if you want to test the admin
   redirect path.

## Notes on things you'll need to fill in

- **Fonts**: `pubspec.yaml` references Manrope font files under
  `assets/fonts/` — download the Manrope family (Google Fonts) and drop the
  four weights in, or swap for a different font family across
  `app_typography.dart` + `pubspec.yaml`.
- **Phone OTP** (`sendOtp`/`verifyOtp` in `auth_remote_datasource.dart`) has a
  simplified synchronous-looking wrapper around Firebase's callback-based
  `verifyPhoneNumber` API — fine for initial wiring, but should be hardened
  with a proper `Completer` before shipping OTP login to production.
- **Cloud Functions** (`backend/functions/`) folder exists but is empty —
  built when we reach order-total server-validation, stock decrement
  transactions, and scheduled sales rollups.

## Next module

Home + Categories + Products (catalog browsing) — same
data/domain/presentation build-out as Authentication.
