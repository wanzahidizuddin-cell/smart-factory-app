# Smart Factory Quality & Inventory (Flutter)

Paperless quality-control app for factory shop-floor staff, built on the InvWise
industrial rules. It includes the app shell, authentication, Home, Deliveries,
Inventory, Production Inspection, Trace, and Profile screens.

## 1. Set up

```bash
flutter create smart_factory_qc --platforms=ios,android
cd smart_factory_qc
# replace pubspec.yaml and the lib/ folder with the ones from this zip
mkdir -p assets/fonts
# add Inter (Regular, Medium, SemiBold, Bold) and RobotoMono (Regular, Medium, Bold)
# .ttf files to assets/fonts/ using the names declared in pubspec.yaml
flutter pub get
flutter run
```

Apply `supabase/schema.sql` to the Supabase project before using profile approval,
dashboard counts, and management. Existing deployments should apply the updated
profile role/status constraints, low-stock view, and RLS policies as well.

Requires Flutter 3.27+ (uses `CardThemeData`, `WidgetState`, `Color.withValues`).
Run it in the iPhone 14 simulator (390x844). Fonts are bundled rather than fetched at
runtime because the app must work offline on the shop floor.

If a pinned version in `pubspec.yaml` is stale, run `flutter pub add <package>` to get the latest.

### iOS permissions (ios/Runner/Info.plist)
```xml
<key>NSCameraUsageDescription</key>
<string>Camera is used to scan batch and serial barcodes and attach defect photos.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photos can be attached to inspection records.</string>
```
Android: `android.permission.CAMERA` in AndroidManifest.xml.

## 2. Folder structure

```
lib/
  main.dart                      app entry, portrait lock, login gate
  app/
    app_shell.dart               bottom navigation + pinned offline banner
    sync_status.dart             offline flag + pending-record count
  core/
    theme/app_colors.dart        palette (navy, accent blue, slate, status colours)
    theme/app_theme.dart         spacing, text styles, ThemeData
    utils/format.dart            number / time formatting
    widgets/                     shared labels, status, offline and responsive widgets
  domain/                        pure Dart, no Flutter/UI imports except enums
    models/                      batch_status, delivery, inventory, activity_entry
    repositories/                stock_movement_repository (append + read only)
    stock_calculator.dart        total stock = SUM(stock_levels), low-stock rule
  data/
    dummy_data.dart
    repositories/                Supabase repositories and app settings
  features/
    auth/screens/login_page.dart
    home/home_screen.dart
    deliveries/                  delivery list, details and release flow
    inspections/                  production inspection form
    inventory/inventory_screen.dart
    profile/profile_screen.dart
    shared/providers/app_state.dart
    trace/trace_search_screen.dart
```

## 3. How the InvWise rules show up in code

| Rule | Where |
|---|---|
| No client sign-up | `login_screen.dart` has sign-in only, with a note that admins provision accounts |
| No stored total quantity | `InventoryItem` has no quantity field; `totalStock()` sums `StockLevel`s |
| Immutable stock movements | `StockMovement` is all-final with no `copyWith`; `StockMovementRepository` exposes only `append` and `history` |
| Profile access control | Supabase restricts role/status changes to approved Admin/QA Lead accounts |
| Tab state retention | Global preferences and async collection providers remain alive across tab changes |
| 48px touch targets | `AppTheme` sets minimum sizes on buttons, inputs, chips, icon buttons; nav bar is 72px; primary buttons are 56px |
| Status never colour-only | `StatusBadge` pairs colour with icon and text |

The client-side rules are a convenience. The server must still enforce them (no UPDATE/DELETE
grants on the movements table, server-only user creation).

## 4. Current scope

The current app includes Deliveries, Inventory, Production Inspection, Trace,
offline inventory caching, queued inspection sync, role-gated user management,
an admin audit log, and simulated hardware telemetry.

## 5. Offline sync and role-protected features

The app uses Drift/SQLite for the local inventory cache and a durable `sync_queue`.
Inspections and append-only stock movements are written to the queue before any
network request; queued actions are retried on connectivity changes and remain
visible in Sync status when a server mutation fails.

User roles map the existing `profiles.role` values (`Admin`, `QA Lead`, `QA`,
`Warehouse`) to the app's `AppRole`. Admin-only audit history and Admin/QA Lead
user management are guarded in the UI; Supabase RLS remains authoritative.
Hardware telemetry is currently a deterministic-shape mock stream, not a live
device connection.

Apply the updated `supabase/schema.sql` to add inspection idempotency, audit
logging, and the hardware device registry. Existing deployments should apply the
whole idempotent schema in the Supabase SQL editor after taking their normal
database backup.

## 6. Activation portal (React)

The separate `activation-portal/` app is a Vite + React + TypeScript admin portal.
Install and run it with:

```powershell
cd activation-portal
npm install
Copy-Item .env.example .env.local
# Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY in .env.local
npm run dev
```

The portal accepts approved Admin sign-ins only. Employee invitations are
created through the `provision-employee` Supabase Edge Function, which validates
the caller's role server-side and uses the service-role key only in the function
environment. Never put a service-role key in the portal's `VITE_*` variables.
Deploy the function with `supabase functions deploy provision-employee` after
applying the schema and setting the function's service-role secret with
`supabase secrets set SUPABASE_SERVICE_ROLE_KEY="<service-role-secret>"`.
Keep that value out of the portal environment and source control. Bulk CSV
imports require the columns `full_name`, `employee_id`, `email`, and `role`.
