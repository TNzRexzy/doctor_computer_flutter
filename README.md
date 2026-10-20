# Doctor Computer Application

Production-ready cross-platform computer retail and interactive PC configurator system built with Flutter, Provider architecture, Supabase backend integration, OpenStreetMap geospatial services, and Google Gemini AI.

* **Application Name:** Doctor Computer
* **Release Version:** 1.0.7-beta
* **Target Platforms:** Android, iOS, Windows, Web
* **Engine:** Flutter 3.47+ / Dart 3.13+

---

## Technical Architecture Overview

Doctor Computer utilizes a decoupled, reactive architecture adhering to clean Flutter development principles:

* **Presentation Layer:** Declarative UI widgets with reactive state listeners via `Provider` pattern.
* **State Management:** Scoped `ChangeNotifier` providers (`AuthProvider`, `CartProvider`, `ProductProvider`, `PcBuilderProvider`, `OrderProvider`, `BlockchainProvider`, `WishlistProvider`, `NotificationProvider`, `ThemeProvider`).
* **Data Layer & Remote Persistence:** Supabase PostgreSQL with PostgREST API client, row-level security resilience, and local caching fallback via `SharedPreferences`.
* **Geospatial & Mapping Engine:** OpenStreetMap tile integration via `flutter_map` with real-time reverse geocoding through Nominatim HTTP endpoints.
* **Artificial Intelligence Engine:** Context-aware assistant and heuristic search algorithms integrated with Google Gemini API runtime database loaders.

---

## Role-Based Access Control (RBAC) Specification

The system implements strict role-based authorization to divide administrative functions from customer-facing interfaces.

### Built-in Verification Accounts

| Role | Username / Identity | Credential | Authorization Scope |
|---|---|---|---|
| Administrator | `admin` or `admin@doctorcomputer.id` | `admin123` / `Admin@DC2026!` | Full administrative dashboard access; modify product stock and catalog pricing; update order fulfillment statuses; manage customer records (arbitrary points/EXP modification, tier reassignment, role elevation); store sales performance metrics. |
| Cashier | `cashier` or `cashier@doctorcomputer.id` | `cashier123` / `Cashier@DC2026!` | Dedicated cashier panel; inventory stock level adjustments; order dispatch and fulfillment status updates. |
| Customer (Default) | Standard registration flow | User defined | Product browsing, custom PC assembly configurator, checkout and order placement, interactive delivery location selection, warranty tracking, AI consultation, loyalty EXP accrual. |

*Note: All newly registered accounts default automatically to the Customer (`user`) role.*

---

## Major Changes & Implementations

### 1. Geospatial Map Address Picker & Database Synchronization
* **Interactive Map Integration:** Implemented `LocationPickerScreen` using OpenStreetMap raster tiles through `flutter_map` (v8.3+) and `latlong2`. Users can drag, pan, zoom, and pinpoint precise coordinates on the map.
* **Reverse Geocoding Engine:** Coordinate changes trigger asynchronous queries to the Nominatim reverse geocoding API, extracting street names, urban districts, postal codes, and city jurisdictions.
* **Address Search & Quick Presets:** Integrated text query search for Indonesian regions alongside quick-navigation shortcuts for major metropolitan areas (Jakarta Pusat, Jakarta Selatan, Bandung, Surabaya, Yogyakarta, Medan).
* **Database Persistence:** Confirmed location results automatically update the logged-in user profile in Supabase (`latitude`, `longitude`, `address`, `city`).
* **Checkout & Profile Interoperability:** Both checkout and profile forms pre-populate from stored database coordinates, eliminating duplicate address entry.

### 2. Administrative Operations & Management Dashboard
* **Dynamic Role Dashboard Routing:** Implemented `AdminDashboardScreen` supporting tabbed operations for inventory, transactions, user administration, and key metrics.
* **Stock & Pricing Management:** Real-time modal editor allowing administrators and cashiers to adjust catalog inventory counts and unit pricing with direct database updates.
* **Fulfillment Pipeline:** Status transition handling (`Processing`, `Shipped`, `Delivered`, `Cancelled`) with synchronized state persistence in remote transaction records.
* **User Management & Gamification Control:** Administrative capabilities to inspect user accounts, reassign membership tiers (`Bronze`, `Silver`, `Gold`, `Platinum`), and manually adjust reward EXP/points balances.
* **Analytical Overview:** Real-time calculation of gross revenue, active inventory volume, total order count, and low-stock warning indicators.

### 3. Artificial Intelligence Engine & Semantic Search Refactoring
* **Context-Aware Customer Support:** Overhauled `GeminiService` customer support module to eliminate hardcoded response templates, introducing dynamic heuristic matching and runtime API key retrieval from the Supabase `app_settings` table.
* **Category-Prioritized Smart Search:** Refactored search index matching to enforce category exclusivity before textual relevance (e.g., queries for "SSD" isolate components under storage classifications rather than laptops containing SSD spec mentions).
* **Deterministic Bottleneck & FPS Calculator:** Deployed an 8-game benchmark evaluation database across 10 hardware performance tiers (Cyberpunk 2077, Red Dead Redemption 2, Valorant, GTA V, Black Myth: Wukong, Forza Horizon 5, Counter-Strike 2) with color-coded performance thresholds (Green: >=60 FPS, Yellow: 30-59 FPS, Red: <30 FPS).

### 4. End-to-End PC Builder Cart Integration
* Connected interactive PC configurator selections directly to `CartProvider`.
* Every selected hardware component (CPU, GPU, Motherboard, RAM, Storage, PSU, Case, Cooler) is normalized into a `ProductModel` instance with associated assembly service line items (Standard or Premium assembly tier) and transferred to the checkout pipeline.

### 5. Checkout Navigation & Route History Stabilization
* Resolved critical blank screen defect post-purchase.
* Normalized all `MaterialPageRoute` declarations within `AppRouter` to preserve route settings metadata (`settings: settings`).
* Post-checkout confirmation now triggers a clean stack purge via `pushNamedAndRemoveUntil(context, AppRouter.mainNav, (route) => false)` followed immediately by `AppRouter.orderHistory`, displaying the newly generated Order ID and transaction summary.

### 6. Dual-Mode Catalog Presentation
* Added layout toggle capability to `CatalogScreen`, supporting switching between dense multi-column Grid View and comprehensive List View with detailed component specifications.

### 7. Profile Picture Database Synchronization
* Enabled profile image modification via remote URL dialog, persisting image references directly into the `profile_image_url` field of the Supabase user schema.

### 8. Dynamic Membership Synchronization & Admin Full-Privilege State
* **Cross-Screen Progress Synchronization:** Unified loyalty progress calculations between `ProfileScreen` and `MemberScreen` via `BlockchainProvider`. The progress bar dynamically visualizes true fractional distance between tiers (`((totalExp - currentTier.value) / (nextTier.value - currentTier.value))`).
* **Administrator Max Status:** Accounts authenticated with the `admin` role are assigned maximum parameters: Platinum Tier (`0xFFE5E4E2`), 999,999 EXP, full progress visualization (1.0), and full access badges across all profile and membership views.

---

## Minor Changes & System Optimizations

1. **User Interface Language Standardization:** Removed all composite bilingual strings (e.g., "Masuk / Login", "Alamat / Address", "Cari / Search") across 15+ screens in favor of clean, consistent Indonesian terminology.
2. **Database Query Coercion Hardening:** Replaced fragile `.single()` and `.maybeSingle()` PostgREST invocations with deterministic `.limit(1)` queries in `AuthProvider`, resolving runtime exceptions (`PostgrestException: Cannot coerce the result to a single JSON object`) caused by duplicate records.
3. **Database Schema Fallback Handling:** Implemented defensive schema mapping to gracefully handle environments where new columns (`role`, `profile_image_url`, `latitude`, `longitude`) are pending migration, preventing `PGRST204` crashes during registration.
4. **Registration Error Handling:** Enhanced authentication exception handling to intercept HTTP 422 errors and display clear duplicate account notices.
5. **Flexible Authentication Input:** Extended the login credential validator to accept identity aliases (`admin`, `cashier`) alongside standard email formats.
6. **Application Version Metadata:** Synchronized application build metadata across dialogs, constants, and `pubspec.yaml` to display `Beta v1.0.7-beta`.
7. **Code Analysis & Lint Compliance:** Eliminated unused imports, corrected 8-digit hexadecimal color values, and resolved asynchronous context gap warnings. The codebase passes `flutter analyze` with 0 issues.

---

## Issue Resolution Matrix

| Defect ID | Description | Root Cause | Status |
|---|---|---|---|
| BUG-001 | Google and Apple authentication buttons unresponsive | Handler callbacks were unassigned empty closures | Resolved (Informational modal and notification dispatched) |
| BUG-002 | Home screen PC Builder button hides navigation bar and triggers unprompted theme switch | Button invoked `Navigator.pushNamed` instead of delegating to parent `MainNavScreen` tab index | Resolved (Switches tab index via `MainNavScreenState.switchToTab(2)`) |
| BUG-003 | AI Customer Support responses strictly templated | Absence of API key loading and rudimentary fallback logic | Resolved (Runtime Supabase key loader and contextual heuristic engine deployed) |
| BUG-004 | PC Builder selections do not persist to shopping cart | Confirmation dialog lacked execution calls to `CartProvider` | Resolved (Component normalization and service fee dispatch implemented) |
| BUG-005 | Post-purchase blank screen | `Navigator.popUntil` failed to identify route due to missing `RouteSettings` in router | Resolved (RouteSettings attached across router; deterministic navigation to order history deployed) |
| BUG-006 | AI Smart Search category pollution | Query algorithm evaluated textual description tokens before category categorization | Resolved (Category-first isolation implemented) |
| BUG-007 | Database schema cache error on register (PGRST204) | Insert query passed uncommitted schema columns | Resolved (Standardized core schema insert with fallback role resolution) |
| BUG-008 | PostgREST single object coercion failure on login | Multiple matching rows triggered coercion exceptions on `.single()` | Resolved (Transitioned to `.limit(1)` query format) |
| BUG-009 | Admin user editing does not persist to database | Supabase RLS blocks cross-user updates; no `role` column in schema | Resolved (Dual persistence with SharedPreferences cache + RLS policy migration) |
| BUG-010 | Blank white screen upon triggering Flash Sale dialog | Unbounded layout constraints on Slider in dialog and type cast exceptions on numeric price strings | Resolved (Replaced dialog with constrained modal bottom sheet, bounded box layout, and defensive numeric parsing) |
| BUG-011 | App stuck before splash screen (runApp never reached) | `AuthProvider` constructor called `restoreSession()` fire-and-forget while `main()` awaited it again, causing a race condition on Supabase and SharedPreferences | Resolved (Removed duplicate `restoreSession()` call from constructor) |
| BUG-012 | Undefined identifier `user` in admin dashboard | `user` variable referenced in admin blockchain sync was never declared in scope | Resolved (Replaced with `context.read<AuthProvider>().currentUser`) |
| BUG-013 | `use_build_context_synchronously` warning in admin dashboard | `context.read<BlockchainProvider>()` called after async gap without mounted check | Resolved (Added `if (!ctx.mounted) return;` guard before async context usage) |
| BUG-014 | `invalid_constant` error in product detail screen | `const Icon` used with non-const `AppColors.error` color value | Resolved (Removed `const` keyword from Icon constructor) |

---

## Version 1.0.7-beta Changelog

1. **Critical Startup Race Condition Fix:** Eliminated duplicate `restoreSession()` invocation — constructor fired it without `await` while `main()` awaited it again, causing concurrent Supabase/SharedPreferences access that could hang the app before the UI ever rendered.
2. **Admin Dashboard Undefined Identifier Fix:** Resolved `undefined_identifier` error where `user` variable was referenced but never declared in the admin blockchain points sync dialog; replaced with proper `context.read<AuthProvider>().currentUser`.
3. **Async Context Safety:** Added `mounted` guard before `context.read<BlockchainProvider>()` call that occurred after an async gap in admin user editing flow.
4. **Const Correctness Fix:** Removed invalid `const` keyword from `Icon` widget using non-const `AppColors.error` color in product detail Flash Sale badge.
5. **Code Analysis Compliance:** Codebase passes `flutter analyze` with 0 issues.

---

## Version 1.0.5-beta Changelog

1. **Dedicated Flash Sale Management Tab:** Separated Flash Sale into its own dedicated menu tab in both Admin (Tab 2 of 6) and Cashier (Tab 2 of 4) dashboards.
2. **Real-Time Flash Sale Countdown Controller:** Real-time countdown timer controls with live seconds ticker, quick extension presets (+2h, +6h, +12h, +24h, +3d), and custom date/time picker, syncing globally with the Home Screen `FlashDealTimer` and product catalog.
3. **Flash Sale Blank White Screen Defect Resolution:** Solved dialog crash resulting in white screen by implementing `_FlashSaleSheetWidget` modal bottom sheet with bounded max-width constraints, safe numeric parsers (`_parseDouble`, `_parseInt`), and interactive discount percentage slider.
4. **Active Flash Sale Product Catalog:** Dashboard tab displays all active Flash Sale items with promo discounts, sale price vs strike-through original price, stock remaining, and one-click removal/adjustment controls.
5. **Quality of Life (QoL) Multi-Resolution Support:** Adaptive layouts using `LayoutBuilder` that automatically scale between single-column mobile views and multi-column grid views for tablets and wide screens. Responsive headers with `Wrap` to prevent overflow on small screens.
6. **Strict Enterprise Tone (Zero Emojis):** Completely eliminated all emojis from notifications, banners, checkout modals, game rewards, and user greeting headers across the codebase.

---

## Version 1.0.4-beta Changelog

1. **Admin Product Management:** Full CRUD operations for products in the admin/cashier dashboard -- add new products, edit name/brand/price/stock/description, and delete products with Supabase sync and local cache fallback.
2. **Flash Sale Configuration:** Admin and cashier can toggle Flash Sale status on any product, configure discount percentage via slider, set sale price and original price, with real-time product catalog updates.
3. **Review Reply System:** Admin and cashier can reply to customer reviews from a dedicated Reviews tab. Replies display as "Respon Penjual" cards on both the admin dashboard and the public product detail screen, persisted via SharedPreferences cache and Supabase sync.
4. **User Access Editing Fix:** Admin user management now correctly persists role, tier, name, and points changes. Implements dual-write strategy (Supabase update + SharedPreferences cache) so changes take effect immediately even if Supabase RLS rejects the remote write.
5. **ReviewProvider Architecture:** New centralized `ReviewProvider` managing review data from mock, Supabase, and local cache with merge strategy. Registered globally via `MultiProvider`.
6. **ProductModel Enhancement:** Added `copyWith`, `toMap`, and `fromMap` methods to `ProductModel` for admin CRUD serialization.
7. **SQL Migration:** Added `supabase/migrations/add_admin_features.sql` with role column, review reply columns, and RLS policies for admin operations.

---

## Backlog & Future Enhancements

* **Native Social Authentication:** Implementation of native OAuth SDKs for Google Sign-In and Sign in with Apple.
* **Dynamic Multi-Language Switcher:** Infrastructure for runtime locale switching between Indonesian, English, and Japanese.
* **Automated Payment Gateway:** Integration with external payment gateway sandbox environments (Midtrans Snap / Xendit) to replace the current simulation pipeline.

---

## Database Schema & Migration Reference

To synchronize remote Supabase databases with the application schema, execute the following Data Definition Language (DDL) statements within the Supabase SQL Editor:

```sql
-- Extend public.users table with metadata columns
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS profile_image_url TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

-- Ensure public.orders transaction table exists
CREATE TABLE IF NOT EXISTS public.orders (
    id TEXT PRIMARY KEY,
    user_id TEXT,
    total_price DOUBLE PRECISION,
    status TEXT DEFAULT 'processing',
    order_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    shipping_address TEXT,
    payment_method TEXT,
    tracking_number TEXT,
    courier TEXT,
    serial_number TEXT,
    warranty_months INTEGER DEFAULT 12,
    rating DOUBLE PRECISION,
    review_comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

## Development Environment & Execution

### Prerequisites
* Flutter SDK (3.24.0 or higher recommended)
* Dart SDK (3.5.0 or higher recommended)
* Active internet connectivity for Supabase and OpenStreetMap services

### Setup Procedure

1. Verify environment health:
   ```bash
   flutter doctor
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run static code analysis:
   ```bash
   flutter analyze
   ```

4. Launch target application:
   ```bash
   flutter run
   ```
