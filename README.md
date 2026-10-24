# Doctor Computer Application

Production-ready cross-platform computer retail, omnichannel POS system, interactive PC configurator, and blockchain loyalty rewards application built with Flutter, Provider architecture, Supabase PostgreSQL backend integration, OpenStreetMap geospatial services, and Google Gemini AI.

* **Application Name:** Doctor Computer
* **Release Version:** 1.0.8-beta
* **Target Platforms:** Android, iOS, Windows, Web
* **Engine:** Flutter 3.24+ / Dart 3.5+

---

## Technical Architecture Overview

Doctor Computer utilizes a decoupled, reactive architecture adhering to clean Flutter development principles:

* **Presentation Layer:** Declarative UI widgets with reactive state listeners via `Provider` pattern.
* **State Management:** Scoped `ChangeNotifier` providers (`AuthProvider`, `CartProvider`, `ProductProvider`, `PcBuilderProvider`, `OrderProvider`, `BlockchainProvider`, `WishlistProvider`, `NotificationProvider`, `ThemeProvider`, `ReviewProvider`).
* **Data Layer & Remote Persistence:** Supabase PostgreSQL with PostgREST API client, database triggers, Row-Level Security (RLS) enforcement, and resilient local caching fallback via `SharedPreferences`.
* **Omnichannel POS & Shift Engine:** PostgreSQL RPC functions (`create_pos_order`, `provision_staff`), automatic inventory decrement triggers (`stock_movements`), and real-time cashier shift reconciliation (`cashier_shifts`).
* **Blockchain Loyalty Ledger:** Cryptographically chained blocks (SHA-256) tracking user EXP gains, minigame rewards, and membership tier upgrades, synchronized bidirectionally between local device storage and the Supabase `blockchain_blocks` table.
* **Geospatial & Mapping Engine:** OpenStreetMap tile integration via `flutter_map` with real-time reverse geocoding through Nominatim HTTP endpoints.
* **Artificial Intelligence Engine:** Context-aware assistant and heuristic search algorithms integrated with Google Gemini API runtime database loaders.

---

## Role-Based Access Control (RBAC) Specification

The system implements strict role-based authorization dividing administrative functions, cashier point-of-sale operations, and customer-facing interfaces. Database roles match the PostgreSQL `roles` table foreign key constraint (`admin`, `cashier`, `client`).

### Built-in Verification Accounts

| Role | Username / Identity | Credential | Authorization Scope |
|---|---|---|---|
| Administrator | `admin` or `admin@doctorcomputer.id` | `admin123` / `Admin@DC2026!` | Full administrative dashboard access; modify product stock and catalog pricing; manage Flash Sales; omnichannel order fulfillment; customer administration; staff provisioning via `provision_staff` RPC; store sales & cashier shift monitoring. |
| Cashier (Kasir) | `cashier` or `cashier@doctorcomputer.id` | `cashier123` / `Cashier@DC2026!` | Dedicated POS & Cashier dashboard; open and close cashier shifts with cash variance reconciliation; process offline walk-in store orders via `create_pos_order`; generate and print digital receipts; instant inventory stock checker. |
| Client / Customer | Standard registration flow | User defined | Product browsing, custom PC assembly configurator, checkout and order placement, interactive delivery location selection, warranty tracking, AI consultation, minigames & blockchain loyalty EXP accrual. |

*Note: All newly registered accounts default automatically to the Customer (`client`) role.*

---

## Major Changes & Implementations

### 1. Dedicated Cashier & POS Dashboard (`CashierDashboardScreen`)
* **Dedicated Route & Headquarters:** Added `AppRouter.cashierDashboard` (`/cashier-dashboard`) with direct access from the user profile for `cashier` and `admin` roles.
* **Point of Sale (POS) Cashier Interface:**
  * Real-time product search and category filters (Laptops, PC Parts, Monitors, Accessories, Audio).
  * Live stock availability badges (Ready, Low Stock `< 5`, Out of Stock).
  * Interactive POS cart drawer with quantity increments and inventory ceiling validation.
  * Payment modal supporting **Cash (Tunai)**, **QRIS**, and **Debit BCA**.
  * Quick-cash tender shortcuts (`Uang Pas`, `50rb`, `100rb`, `200rb`, `500rb`) with real-time change calculation.
  * Integration with PostgreSQL RPC `create_pos_order` (and local fallback) to create POS orders and auto-deduct stock via `stock_movements`.
  * Digital thermal receipt modal with transaction metadata, cashier ID, itemized totals, and simulated POS printer dispatch.
* **Cashier Shift Management & Reconciliation:**
  * Open shift workflow with drawer starting cash (`opening_cash`) and operational notes.
  * Active shift status indicator (OPEN / CLOSED pill) in the dashboard header.
  * Close shift modal with expected drawer cash computation (`opening_cash + total_sales`), actual cash input, and automatic variance calculation (Pas, Lebih, Kurang).
  * Resilient dual persistence: shifts write to Supabase `cashier_shifts` with automatic `SharedPreferences` session fallback.
* **Store POS Order Log & Stock Checker:**
  * Filterable log of offline store transactions with search by transaction number.
  * Fast stock checker tab to assist store personnel in answering customer availability inquiries.

### 2. Blockchain Cloud Synchronization & EXP Loyalty Ledger
* **Supabase Cloud Sync:** Upgraded `BlockchainProvider` to synchronize blocks with the Supabase `blockchain_blocks` table on every mine operation.
* **Reward Integration:** Shopping reward blocks (`CheckoutScreen`) and minigame rewards (`MemoryMatchGame`, `PcQuizGame`, `SpeedRepairGame`) automatically record blocks to the cloud ledger with user ID attribution.
* **Database Trigger Integration:** Synchronized user EXP points and tier upgrades via PostgreSQL `SECURITY DEFINER` triggers (`sync_user_points_from_blockchain`, `sync_user_tier_from_blockchain`), eliminating RLS privilege errors and preventing EXP double-counting.
* **Genesis Block Verification:** Automatically creates and syncs the Genesis block to the cloud upon user registration and login.
* **Blockchain Ledger Viewer:** Added manual cloud refresh and interactive pull-to-refresh on `BlockchainLedgerScreen`.

### 3. Omnichannel Admin Dashboard & Staff Provisioning
* **Omnichannel Order Filtering:** Added channel filters (`Semua`, `Online`, `POS Kasir`) with visual indicators on orders.
* **Staff Provisioning Dialog:** Admin tab now includes a "Tambah Staff" button that calls the PostgreSQL RPC `provision_staff(p_email, p_password, p_full_name, p_role, p_created_by)` to safely create official Cashier and Admin credentials.
* **Role Alignment:** Updated user management to adhere strictly to database role constraints (`admin`, `cashier`, `client`).
* **Omnichannel Analytics:** Statistics tab expanded to display revenue breakdowns (Total, Online vs POS) and live cashier shift monitoring.

### 4. Geospatial Map Address Picker & Database Synchronization
* **Interactive Map Integration:** Implemented `LocationPickerScreen` using OpenStreetMap raster tiles through `flutter_map` (v8.3+) and `latlong2`. Users can drag, pan, zoom, and pinpoint precise coordinates on the map.
* **Reverse Geocoding Engine:** Coordinate changes trigger asynchronous queries to the Nominatim reverse geocoding API, extracting street names, urban districts, postal codes, and city jurisdictions.
* **Address Search & Quick Presets:** Integrated text query search for Indonesian regions alongside quick-navigation shortcuts for major metropolitan areas.
* **Database Persistence:** Confirmed location results automatically update the logged-in user profile in Supabase (`latitude`, `longitude`, `address`, `city`).

### 5. Artificial Intelligence Engine & Semantic Search Refactoring
* **Context-Aware Customer Support:** Overhauled `GeminiService` customer support module to eliminate hardcoded response templates, introducing dynamic heuristic matching and runtime API key retrieval from the Supabase `app_settings` table.
* **Category-Prioritized Smart Search:** Refactored search index matching to enforce category exclusivity before textual relevance.
* **Deterministic Bottleneck & FPS Calculator:** Deployed an 8-game benchmark evaluation database across 10 hardware performance tiers with color-coded performance thresholds.

### 6. End-to-End PC Builder Cart Integration
* Connected interactive PC configurator selections directly to `CartProvider`.
* Every selected hardware component is normalized into a `ProductModel` instance with associated assembly service line items and transferred to the checkout pipeline.

---

## Issue Resolution Matrix

| Defect ID | Description | Root Cause | Status |
|---|---|---|---|
| BUG-001 | Google and Apple authentication buttons unresponsive | Handler callbacks were unassigned empty closures | Resolved (Informational modal and notification dispatched) |
| BUG-002 | Home screen PC Builder button hides navigation bar | Button invoked `Navigator.pushNamed` instead of delegating to tab index | Resolved (Switches tab index via `MainNavScreenState.switchToTab(2)`) |
| BUG-003 | AI Customer Support responses strictly templated | Absence of runtime key loader and heuristic engine | Resolved (Runtime Supabase key loader and contextual heuristic engine deployed) |
| BUG-004 | PC Builder selections do not persist to shopping cart | Confirmation dialog lacked execution calls to `CartProvider` | Resolved (Component normalization and service fee dispatch implemented) |
| BUG-005 | Post-purchase blank screen | `Navigator.popUntil` failed due to missing `RouteSettings` | Resolved (RouteSettings attached across router; deterministic navigation deployed) |
| BUG-006 | AI Smart Search category pollution | Query algorithm evaluated textual tokens before category filter | Resolved (Category-first isolation implemented) |
| BUG-007 | Database schema cache error on register (PGRST204) | Insert query passed uncommitted schema columns | Resolved (Standardized core schema insert with fallback role resolution) |
| BUG-008 | PostgREST single object coercion failure on login | Multiple matching rows triggered coercion exceptions on `.single()` | Resolved (Transitioned to `.limit(1)` query format in `AuthProvider._fetchProfileRow`) |
| BUG-009 | Admin user editing does not persist to database | Supabase RLS blocks cross-user updates; no `role` column in schema | Resolved (Dual persistence with SharedPreferences cache + rewritten RLS policies) |
| BUG-010 | Blank white screen upon triggering Flash Sale dialog | Unbounded layout constraints on Slider in dialog | Resolved (Replaced dialog with constrained modal bottom sheet) |
| BUG-011 | App stuck before splash screen (runApp never reached) | `AuthProvider` duplicate un-awaited `restoreSession()` call | Resolved (Removed duplicate `restoreSession()` call from constructor) |
| BUG-012 | Undefined identifier `user` in admin dashboard | `user` variable referenced in admin blockchain sync was undeclared | Resolved (Replaced with `context.read<AuthProvider>().currentUser`) |
| BUG-013 | `use_build_context_synchronously` warning in admin dashboard | Context accessed across async gap without mounted check | Resolved (Added `if (!ctx.mounted) return;` guard) |
| BUG-014 | `invalid_constant` error in product detail screen | `const Icon` used with non-const `AppColors.error` color value | Resolved (Removed `const` keyword from Icon constructor) |
| BUG-015 | Cross-user account editing rejected by RLS | Restrictive RLS policies and trigger column guards | Resolved (Idempotent RLS policies and `guard_privileged_user_columns` relaxed for points/tier) |
| BUG-016 | PostgREST single-object coercion failure during login sync | Single-object query mode on duplicate records | Resolved (Migrated to `.limit(1)` queries across all session loaders) |
| BUG-017 | Blockchain sync error 42501 on checkout & minigames | Manual update to `users` table blocked by `guard_privileged_user_columns` | Resolved (Delegated points/tier updates to DB triggers with `SECURITY DEFINER`) |
| BUG-018 | Cashier shift open error 42501 (RLS violation) | `cashier_shifts` table only defined SELECT policy, lacking INSERT/UPDATE | Resolved (Added `fix_cashier_shifts_rls.sql` migration + local SharedPreferences session fallback) |

---

## Version 1.0.8-beta Changelog

1. **Point of Sale (POS) & Cashier Dashboard:**
   * Created `CashierDashboardScreen` with Mesin Kasir POS, Shift Management, Store Transactions, and Stock Checker.
   * Integrated `create_pos_order` RPC with auto-inventory deduction, change calculator, and digital receipts.
   * Added Shift opening, closing, and automatic cash variance reconciliation.
2. **Blockchain Cloud Synchronization:**
   * Full synchronization of minigame and shopping rewards to Supabase `blockchain_blocks`.
   * Replaced manual client `users` table updates with `SECURITY DEFINER` database triggers.
3. **Omnichannel Order & Admin Analytics:**
   * Order channel classification (`online` vs `pos`) and filtering chips in admin dashboard.
   * Omnichannel revenue breakdown and real-time cashier shift monitoring in admin stats tab.
   * Staff provisioning dialog calling PostgreSQL RPC `provision_staff`.
4. **Database Migration Scripts:**
   * Added `supabase/migrations/fix_cashier_shifts_rls.sql` for cashier shift and POS order RLS policies.
   * Updated `supabase/migrations/add_admin_features.sql` with relaxed column guards.
5. **Code Health & Quality Assurance:**
   * Clean compilation and static analysis with **0 errors and 0 warnings** across the entire codebase (`flutter analyze lib`).

---

## Database Schema & Migration Reference

To synchronize remote Supabase databases with the application schema, execute the migration scripts located in `supabase/migrations/`:

1. `supabase/migrations/add_admin_features.sql` (Role policies, review replies, staff functions)
2. `supabase/migrations/add_orders_warranty_and_items.sql` (Warranty and order item summaries)
3. `supabase/migrations/fix_cashier_shifts_rls.sql` (Cashier shift and POS order permissions)

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
   flutter analyze lib
   ```

4. Launch target application:
   ```bash
   flutter run
   ```
