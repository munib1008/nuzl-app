# NUZL — Flutter App (mobile + web, one codebase)

The broker-facing frontend for NUZL.AE. Built with Flutter so the **same code runs on iOS, Android, and Web**, wired to the NestJS API. Uses the NUZL design system (emerald/navy/gold, Inter, light/dark).

## Stack
- **Flutter** (Material 3) — mobile + web
- **Riverpod** — state management
- **go_router** — routing with auth guard (real URLs on web)
- **Dio** — HTTP client with a JWT interceptor (auto-attaches the token, catches 401 → redirect to login)
- **flutter_secure_storage** — persists the JWT across sessions (mobile + web)
- **google_fonts** — Inter (and Noto Sans Arabic when you add RTL)

## First run
This package contains `lib/`, `pubspec.yaml`, and `web/`. Generate the platform folders (android/ios/web runners) once, then run:

```bash
cd nuzl_app
flutter create . --org ae.nuzl --project-name nuzl_app --platforms=web,android,ios
flutter pub get

# Run against your local API
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api
# or a device/emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api   # Android emulator → host

# Run against your deployed API
flutter run -d chrome --dart-define=API_BASE_URL=https://your-nuzl-api.vercel.app/api
```

`flutter create .` preserves existing files (it skips `lib/main.dart`, `pubspec.yaml`, `web/index.html` since they already exist) and only adds the missing native runners.

## Structure
```
lib/
  main.dart                      # entry → ProviderScope → NuzlApp
  app.dart                       # MaterialApp.router + theme + session splash
  core/
    theme/                       # design tokens: colors, spacing, typography, ThemeData
    config/env.dart              # API_BASE_URL (via --dart-define)
    network/                     # Dio client, JWT interceptor, endpoint map
    storage/token_storage.dart   # secure JWT persistence
    router/app_router.dart       # go_router + auth-guard redirect
    widgets/                     # EmptyState, StatusBadge, AsyncView
  features/
    auth/                        # login + register (data → controller → screens)
    feed/                        # opportunity feed (the home tab)
    listings/                    # properties + verification status
    leads/                       # buyer requirements + qualification progress
    deals/                       # deals (see note below)
    profile/                     # profile + sign out + theme entry
    shell/main_shell.dart        # 5-tab bottom nav: Feed · Properties · Leads · Deals · Profile
  models/user.dart
```

## How it talks to the API
- `Env.apiBaseUrl` (set via `--dart-define=API_BASE_URL=...`) points at the NestJS API.
- `AuthInterceptor` attaches `Authorization: Bearer <jwt>` to every request and persists the token from `/auth/login` and `/auth/register`.
- On app start, `AuthController.bootstrap()` calls `GET /users/me` with the stored token to restore the session; the router shows a splash until that resolves, then routes to `/feed` or `/login`.
- Screens fetch live data: Feed → `GET /feed`, Properties → `GET /listings`, Leads → `GET /buyer-requirements`, Profile → `GET /users/me`.

## Same-domain deployment (web + API on nuzl.ae)
Flutter Web compiles to static files. Recommended setup that keeps **one origin** (no CORS):

1. Keep the API as its own Vercel project (e.g. `your-nuzl-api.vercel.app`).
2. Build the web app pointing the API at the same origin:
   ```bash
   flutter build web --release --dart-define=API_BASE_URL=/api
   ```
3. Deploy `build/web` as a static Vercel project and attach `nuzl.ae`.
4. The included `vercel.json` proxies `/api/*` → your API project, so the browser only ever sees `nuzl.ae`. **Edit `vercel.json`** and replace `YOUR-NUZL-API.vercel.app` with your real API host.

> Vercel cannot build Flutter natively — build locally or in CI (a `flutter build web` step), then deploy the `build/web` output. For mobile, ship via the App Store / Play Store; the same code, just a different `API_BASE_URL`.

## Notes & honest gaps (scaffold stage)
- **Create flows** (new listing / new lead) have buttons wired but open empty handlers — the forms are the next increment; the data layer + endpoints already exist.
- **Deals tab** shows guidance because the API creates deals on offer-accept but has no `GET /deals` list endpoint yet (a ~15-line backend add against the existing `deals` table).
- **Respond / Save** on feed cards are placeholders pending the respond/save endpoints wiring.
- **Theme toggle** entry exists in Profile; persisting to `PATCH /users/me/theme` is a small follow-up (currently follows system).
- **Flutter version:** structured for **Flutter 3.24+ / Dart 3.4+**. On very new Flutter (3.32+), if you hit type errors on `cardTheme`/`appBarTheme`/`inputDecorationTheme`, rename the value classes to their `...Data` variants (`CardThemeData`, `AppBarThemeData`, `InputDecorationThemeData`) — the values are identical, only the class names changed.

## Branding (logo + app icon)
- The flowing-"n" logo is wired into the **login and register screens** via `lib/core/widgets/nuzl_logo.dart` (mark + "nuzl" wordmark in Poppins, auto-tinted for light/dark).
- Logo asset: `assets/logo/nuzl_mark.svg`. Master brand sheet: `../docs/nuzl-logo.svg`.
- **App icon:** `assets/icon/nuzl_icon.png` (1024×1024). Generate all platform sizes with one command after `flutter pub get`:
  ```bash
  dart run flutter_launcher_icons
  ```
  This creates Android, iOS, and web icons automatically (config is in `pubspec.yaml`).
- Colors live in `lib/core/theme/app_colors.dart` (emerald `#0F6B5B`, deep `#0A4D42`, teal `#1E9C85`, gold `#C8A45D`). Fonts: Poppins (headings/logo) + Inter (body).
