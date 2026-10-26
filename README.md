# Doctor Computer Application

Production-ready cross-platform computer retail, omnichannel POS system, interactive PC configurator, and blockchain loyalty rewards application built with Flutter, Provider architecture, Supabase PostgreSQL backend integration, OpenStreetMap geospatial services, and Google Gemini AI.

* **Application Name:** Doctor Computer
* **Release Version:** 1.1.4-beta
* **Target Platforms:** Android, iOS, Windows, Web
* **Engine:** Flutter 3.24+ / Dart 3.5+

---

## Technical Architecture Overview

Doctor Computer utilizes a decoupled, reactive architecture adhering to clean Flutter development principles:

* **Presentation Layer:** Declarative UI widgets with reactive state listeners via `Provider` pattern.
* **State Management:** Scoped `ChangeNotifier` providers (`AuthProvider`, `CartProvider`, `ProductProvider`, `PcBuilderProvider`, `OrderProvider`, `BlockchainProvider`, `WishlistProvider`, `NotificationProvider`, `ThemeProvider`, `ReviewProvider`).
* **Data Layer & Remote Persistence:** Supabase PostgreSQL with PostgREST API client, database triggers, Row-Level Security (RLS) enforcement, and local caching for non-authoritative display data.
* **Omnichannel POS & Shift Engine:** Authenticated PostgreSQL RPCs calculate prices, lock/decrement inventory, persist order items, and reconcile cashier shifts atomically.
* **Loyalty Points:** Customer points and tiers are database-owned; 500 points are awarded once when an online order is marked delivered. Client-generated hash-chain/minigame data is not authoritative, and minigame EXP is disabled until server-side score verification is implemented.
* **Geospatial & Mapping Engine:** OpenStreetMap tile integration via `flutter_map` with real-time reverse geocoding through Nominatim HTTP endpoints.
* **Artificial Intelligence Engine:** Doctor AI (floating round chat) and AI Smart Search call the Gemini API with automatic fallback between Flash models when a quota limit is hit; the Gemini API key is stored in the Supabase table `app_config` (`key = 'GEMINI_API_KEY'`, see `supabase/migrations/20261030_app_config.sql`) and is not hardcoded in the app (the `gemini-chat` Edge Function remains available as server-side alternative).

---

## Role-Based Access Control (RBAC) Specification

The system implements strict role-based authorization dividing administrative functions, cashier point-of-sale operations, and customer-facing interfaces. Database roles match the PostgreSQL `roles` table foreign key constraint (`admin`, `cashier`, `client`).

Staff accounts must be provisioned by a trusted administrator using the server-side `provision-staff` Edge Function. Do not ship or document shared staff credentials. All newly registered accounts receive the customer role; dashboard visibility is only a UI convenience and database authorization is enforced by RLS.

---

## Major Changes & Implementations

### 1. Dedicated Cashier & POS Dashboard (`CashierDashboardScreen`)
* **Dedicated Route & Headquarters:** Added `AppRouter.cashierDashboard` (`/cashier-dashboard`) with direct access from the user profile for `cashier` and `admin` roles.
* **Point of Sale (POS) Cashier Interface:**
  * Real-time product search and dynamic category filters (chips are built from the categories stored in the database that are actually used by products).
  * Product photos on every POS product card, with multi-URL fallback (product `image_url`, uploaded asset matched by name, `products/<id>.jpg`, public storage URL) and a placeholder icon when no image can be loaded.
  * Live stock availability badges (Ready, Low Stock `< 5`, Out of Stock).
  * Interactive POS cart drawer with quantity increments and inventory ceiling validation.
  * Payment modal supporting **Cash (Tunai)**, **QRIS**, and **Debit BCA**.
  * Quick-cash tender shortcuts (`Uang Pas`, `50rb`, `100rb`, `200rb`, `500rb`) with real-time change calculation.
  * Integration with PostgreSQL RPC `create_pos_order` to atomically create POS orders and decrement authoritative stock; failures do not produce receipts.
  * Digital thermal receipt modal with transaction metadata, cashier ID, itemized totals, and simulated POS printer dispatch.
* **Cashier Shift Management & Reconciliation:**
  * Open shift workflow with drawer starting cash (`opening_cash`) and operational notes.
  * Active shift status indicator (OPEN / CLOSED pill) in the dashboard header.
  * Close shift modal with expected drawer cash computation (`opening_cash + total_sales`), actual cash input, and automatic variance calculation (Pas, Lebih, Kurang).
  * Shift operations persist only on the server; offline actions fail explicitly rather than creating a local-only shift.
* **Order Management Tab (`Pesanan`):** Cashiers can search all orders (order ID, status, or tracking number), filter by channel, and update the order status (`processing`, `shipped`, `delivered`, `cancelled`) with the same dialog used by admins, including courier and tracking number (resi) input.
* **Store POS Order Log & Stock Checker:**
  * Filterable log of offline store transactions with search by transaction number.
  * Fast stock checker tab to assist store personnel in answering customer availability inquiries.
* **Product catalog management:** Admins and cashiers can create, edit, and delete products. Product photos are selected as JPG/JPEG, PNG, or WEBP files and uploaded to the public `assets` Supabase Storage bucket under `product-images/`; wait for the upload to finish, then save the product to persist the public object URL in `products.image_url`. The image binary is stored in Storage, not in the database row.

### 2. Loyalty Points & Client-Side Hash-Chain Display
* Customer points and membership tiers are read from the protected `users` profile. Only the server can award purchase points, once an online order is marked delivered.
* Writes to `blockchain_blocks` are revoked for client roles. Existing/local chain entries may be displayed for demonstration and audit context only; they do not award points or authorize discounts.
* Minigame EXP is intentionally disabled until game results can be verified by a trusted server endpoint.

### 3. Omnichannel Admin Dashboard & Staff Provisioning
* **Omnichannel Order Filtering:** Added channel filters (`Semua`, `Online`, `POS Kasir`) with visual indicators on orders.
* **Order Status & Tracking Number (Resi):** Admins and cashiers update order status and enter the courier and resi through a shared dialog (`lib/widgets/common/order_update_dialog.dart`). A resi is required before an online order can be set to `shipped`. Customers only see a resi (and can copy it) after staff have entered it; otherwise the order tracking screen shows "Belum tersedia" and the copy button is disabled.
* **Staff Provisioning Dialog:** Admin tab calls the authenticated `provision-staff` Edge Function, which creates Auth users with the service role and only then assigns a staff role.
* **Role Alignment:** Updated user management to adhere strictly to database role constraints (`admin`, `cashier`, `client`).
* **Omnichannel Analytics:** Statistics tab expanded to display revenue breakdowns (Total, Online vs POS) and live cashier shift monitoring.

### 4. Geospatial Map Address Picker & Database Synchronization
* **Interactive Map Integration:** Implemented `LocationPickerScreen` using OpenStreetMap raster tiles through `flutter_map` (v8.3+) and `latlong2`. Users can drag, pan, zoom, and pinpoint precise coordinates on the map.
* **Reverse Geocoding Engine:** Coordinate changes trigger asynchronous queries to the Nominatim reverse geocoding API, extracting street names, urban districts, postal codes, and city jurisdictions.
* **Address Search & Quick Presets:** Integrated text query search for Indonesian regions alongside quick-navigation shortcuts for major metropolitan areas.
* **Database Persistence:** Confirmed location results automatically update the logged-in user profile in Supabase (`latitude`, `longitude`, `address`, `city`).

### 5. Artificial Intelligence Engine & Semantic Search Refactoring
* **Context-Aware Customer Support:** Gemini requests are sent directly from the app with automatic Flash-model fallback. The Gemini API key is no longer hardcoded: it is read at runtime from the Supabase table `app_config` (`key = 'GEMINI_API_KEY'`, readable by logged-in users only, writable by admins only). The authenticated `gemini-chat` Edge Function (key stored as an Edge Function secret) remains available as a server-side fallback.
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
| BUG-003 | AI Customer Support responses strictly templated | Absence of a secure server-side Gemini integration | Resolved (Contextual requests use the authenticated `gemini-chat` Edge Function; the API key stays server-side) |
| BUG-004 | PC Builder selections do not persist to shopping cart | Confirmation dialog lacked execution calls to `CartProvider` | Resolved (Component normalization and service fee dispatch implemented) |
| BUG-005 | Post-purchase blank screen | `Navigator.popUntil` failed due to missing `RouteSettings` | Resolved (RouteSettings attached across router; deterministic navigation deployed) |
| BUG-006 | AI Smart Search category pollution | Query algorithm evaluated textual tokens before category filter | Resolved (Category-first isolation implemented) |
| BUG-007 | Database schema cache error on register (PGRST204) | Insert query passed uncommitted schema columns | Resolved (Standardized core schema insert with fallback role resolution) |
| BUG-008 | PostgREST single object coercion failure on login | Multiple matching rows triggered coercion exceptions on `.single()` | Resolved (Transitioned to `.limit(1)` query format in `AuthProvider._fetchProfileRow`) |
| BUG-009 | Admin user editing does not persist to database | Supabase RLS blocks cross-user updates; no `role` column in schema | Resolved (Admin edits persist through the authorized `admin_update_user` RPC) |
| BUG-010 | Blank white screen upon triggering Flash Sale dialog | Unbounded layout constraints on Slider in dialog | Resolved (Replaced dialog with constrained modal bottom sheet) |
| BUG-011 | App stuck before splash screen (runApp never reached) | `AuthProvider` duplicate un-awaited `restoreSession()` call | Resolved (Removed duplicate `restoreSession()` call from constructor) |
| BUG-012 | Undefined identifier `user` in admin dashboard | `user` variable referenced in admin blockchain sync was undeclared | Resolved (Replaced with `context.read<AuthProvider>().currentUser`) |
| BUG-013 | `use_build_context_synchronously` warning in admin dashboard | Context accessed across async gap without mounted check | Resolved (Added `if (!ctx.mounted) return;` guard) |
| BUG-014 | `invalid_constant` error in product detail screen | `const Icon` used with non-const `AppColors.error` color value | Resolved (Removed `const` keyword from Icon constructor) |
| BUG-015 | Cross-user account editing rejected by RLS | Restrictive RLS policies and trigger column guards | Resolved (Idempotent RLS policies and `guard_privileged_user_columns` relaxed for points/tier) |
| BUG-016 | PostgREST single-object coercion failure during login sync | Single-object query mode on duplicate records | Resolved (Migrated to `.limit(1)` queries across all session loaders) |
| BUG-017 | Client-controlled blockchain EXP | Client blocks were accepted as the source of member points | Resolved for database balances (client writes revoked; points awarded by delivered-order RPC; minigame rewards disabled pending server verification) |
| BUG-018 | Cashier shift open error 42501 (RLS violation) | `cashier_shifts` table only defined SELECT policy, lacking INSERT/UPDATE | Resolved (Authenticated shift RPCs; local-only shift fallback removed) |
| BUG-019 | Cashier could not update order status or enter a tracking number | Cashier dashboard had no order management tab; no RPC to save the resi | Resolved (New `Pesanan` tab, shared update dialog, and `update_order_tracking` RPC) |
| BUG-020 | Order tracking showed an auto-generated resi that could be copied | `OrderModel` defaulted `trackingNumber` to a hard-coded demo value | Resolved (Default removed; shows "Belum tersedia" with copy disabled until staff enter a resi) |
| BUG-021 | POS checkout failed with PGRST203 (`Could not choose the best candidate function`) | Two overloads of `create_pos_order` existed (`varchar` and `text` parameters) | Resolved (Old overload dropped by `20261028_drop_old_create_pos_order.sql`) |
| BUG-022 | Out-of-stock products could be added to the cart | `CartProvider.addToCart` did not validate stock | Resolved (Stock check in provider, disabled "Stok Habis" button, quantity capped at stock) |
| BUG-023 | POS category chips never filtered products | Chips used hard-coded IDs (`laptops`, `pc_parts`, `monitors`, ...) that do not exist in `categories` | Resolved (Chips are generated from database categories used by the loaded products) |
| BUG-024 | POS product cards had no photo / only some products showed one | No image widget on the card; single URL attempt without the public-URL fallback | Resolved (`_PosImageChain` tries several candidate URLs in order, then shows a placeholder) |
| BUG-025 | Cart item photos missing after the app is reopened | `CartProvider._fetchProductAsync` used raw `image_url` values (relative file names) without `AppImages.resolveProductImages` | Resolved (Images resolved through `AppImages`, same as the catalog) |
| BUG-026 | Irrelevant sample notifications appeared on every login | `NotificationProvider` was seeded with four hard-coded demo notifications (fake order, voucher, reminders) | Resolved (List starts empty; notifications are created only by real events and stored per user) |
| BUG-027 | Gemini API key and Supabase project values were visible in source code, `.env` and `.env.example` | Key was a `defaultValue` in `EnvConfig`; `.env` was tracked by git | Resolved (Key moved to Supabase table `app_config`; `EnvConfig` has no hardcoded values; `.env` is git-ignored and `.env.example` holds placeholders only) |
| BUG-028 | Adding a product failed with `23503` on `fk_products_subtype` | A database-side default/trigger set `products.subtype` to a code missing from `product_subtypes`; the app never sends the column | Resolved (`20261031_fix_product_subtype_fk.sql` normalizes `subtype`/`brand_code` before insert; no app code changed) |
| BUG-029 | Product rating and review count were not real data; reviews were mixed with sample data and device-only cache | Fake fallbacks (`4.5` / `10`) in the product models, `ReviewProvider` merged `mockReviews` and SharedPreferences, and only a whole order (not each product) could be rated | Resolved (rating/count calculated by a database trigger from `reviews`; `ReviewProvider` reads Supabase only; per-item reviews with photo/video through `submit_product_review`) |

---

## Version 1.1.4-beta Changelog

1. **Per-item product reviews with photo and video:**
   * After an order reaches **Selesai**, `Pesanan Saya` lists every product of the order with its own **Beri Ulasan** button (similar to Shopee). The old order-level rating dialog was removed.
   * New `lib/screens/profile/product_review_screen.dart`: star rating, text, up to 5 photos and 1 video (max. 60 seconds) picked from the gallery and uploaded to Supabase Storage (no more typing media URLs). A review can be edited for 7 days after it was first sent, then it is locked.
   * New `lib/services/review_media_service.dart`: picks media, validates type/size (photo 10 MB, video 50 MB, JPG/PNG/WEBP magic-byte check, MP4/MOV/WEBM) and uploads to the `review-media` bucket under the user's own folder.
   * Writes go through the RPC `submit_product_review`: only the owner of an order with status `delivered` that contains the product can review it, media URLs must live in the caller's own storage folder, and the 7-day edit window is enforced on the server.
2. **Reviews shown on the product page:**
   * New `lib/widgets/review/product_reviews_section.dart` under the product description: average rating, 1-5 star distribution, filter **Dengan Foto & Video**, paging (`Lihat ulasan lainnya`), review photos/videos and the seller (admin/cashier) reply.
   * New `lib/widgets/review/review_media_viewer.dart` (`video_player`): full-screen photo viewer with zoom and video playback.
3. **Seller review management (admin and cashier):**
   * New shared `lib/widgets/review/review_management_tab.dart` used by both dashboards: list of buyer reviews with product name, stars, text, **buyer photos/videos** (tap for full screen), seller reply, and a **Belum dibalas** filter.
   * Cashier dashboard now has an **Ulasan** tab (previously only the admin dashboard could see and reply to reviews). Replies are stored in the database and shown on the product page as `Respon Penjual - Admin/Kasir`.
   * Reply templates (tap a chip to fill the reply, then edit): thank you, thank you for photo/video, apology, warranty claim, shipping feedback, general feedback. Positive templates are listed first for 4-5 star reviews and apology templates first for 1-3 stars; `{nama}` is replaced with the buyer's first name.
   * `AdminDashboardScreen`: the old inline review list and reply dialog were replaced by the shared tab.
4. **Ratings now come from real database data (BUG-029):**
   * `products.rating` and `products.review_count` are recalculated by a database trigger from the `reviews` table (average with one decimal).
   * Removed the fake fallback values (rating `4.5` / `10` reviews) from `ProductModel`, `ProductProvider`, `CartProvider` and `WishlistProvider`; they now default to `0`.
   * Products without reviews show **Belum ada ulasan** / **Baru** instead of a fake rating (product card, catalog, product detail).
   * `ProductProvider` no longer lets the locally cached custom products overwrite the rating and review count loaded from the database.
   * `ReviewProvider` was rewritten to read only from Supabase: mock reviews and the SharedPreferences review cache are no longer used, and admin/cashier replies are saved to the database (and report failure instead of silently succeeding).
5. **Database Migration:**
   * Added `supabase/migrations/20261101_product_reviews.sql`: `reviews.order_id`, `media_urls`, `updated_at`; unique review per (order, product, user); public read policy with writes restricted to the RPC (`INSERT`/`DELETE` revoked for clients, staff reply policy kept); rating trigger; `review-media` bucket and storage policies; backfill that recalculates the rating and review count of every product from real reviews.
6. **Dependencies:** added `video_player`.
7. **Versioning:** Bumped app version to `1.1.4-beta+14` (`pubspec.yaml`, `AppConstants.appVersion`).

**Notes:**
* The backfill resets old placeholder ratings: products without reviews become `0` rating / `0` reviews.
* Orders rated with the old order-level rating are not converted; buyers review each product again. The old `orders.rating` columns are kept but no longer used.
* Video items show a play icon tile instead of a generated thumbnail.

**Action required after updating:** run `20261101_product_reviews.sql`, run `flutter pub get`, and rebuild the app.

---

## Version 1.1.3-beta Changelog

1. **Fingerprint login (all roles: client, cashier, admin):**
   * New menu `Profil > Keamanan` (`lib/screens/profile/security_screen.dart`, route `AppRouter.security`) to register and remove fingerprints. Registration asks for the account password, then the real fingerprint scan through the Android system prompt (`local_auth`, `biometricOnly`, so PIN/pattern is rejected).
   * New `lib/services/biometric_service.dart`: sensor status check, fingerprint prompt, registration/removal in `public.user_biometrics`, and `user_security_settings.biometric_enabled` sync.
   * Credentials (email + password) are stored only on the device, encrypted by the Android Keystore (`flutter_secure_storage`); the database stores only a per-device registration record (random `biometric_token`), never the password.
   * `LoginScreen` shows **Masuk dengan Sidik Jari** only when the account that last logged out has a fingerprint registered on that device. An account without a registered fingerprint shows no button after logout.
   * After a fingerprint login the registration must still be active in the database, so a fingerprint removed from another device is rejected and its local credentials are cleared. If the password was changed, the stored credentials are discarded and the user must register again.
   * Registrations are per device: logging in on another phone does not carry the fingerprint over.
   * `AuthProvider`: added `loginWithBiometric()` and three `rememberLastUser` calls (`login`, `restoreSession`, `logout`); the existing login flow is unchanged.
2. **Add product error `fk_products_subtype` (BUG-028):**
   * A database-side default/trigger filled `products.subtype` with a code that does not exist in `product_subtypes`, so inserting a product failed with `23503`. The app never sends `subtype`/`brand_code`.
   * Added `supabase/migrations/20261031_fix_product_subtype_fk.sql`: last-running `zz_` triggers that map an invalid `subtype` from the product category (fallback `GEN`) and null an invalid `brand_code` for `products`; invalid codes become `NULL` for `pc_parts`. No Flutter code changed.
3. **Database Migration:**
   * Added `supabase/migrations/20261031_biometric_login.sql` (`user_biometrics` and `user_security_settings` with own-row RLS, unique index on `biometric_token`).
4. **Android / iOS configuration (required by `local_auth`):**
   * `MainActivity` now extends `FlutterFragmentActivity`.
   * `AndroidManifest.xml`: added `USE_BIOMETRIC` permission.
   * `values/styles.xml` and `values-night/styles.xml`: `LaunchTheme`/`NormalTheme` parents changed to AppCompat.
   * `ios/Runner/Info.plist`: added `NSFaceIDUsageDescription`.
5. **Dependencies:** added `local_auth` and `flutter_secure_storage`.
6. **Versioning:** Bumped app version to `1.1.3-beta+13` (`pubspec.yaml`, `AppConstants.appVersion`).

**Action required after updating:** run `20261031_fix_product_subtype_fk.sql` and `20261031_biometric_login.sql`, run `flutter pub get`, and do a full rebuild (native Android changes are not applied by hot reload).

---

## Version 1.1.2-beta Changelog

1. **Gemini API key no longer hardcoded:**
   * Removed the hardcoded `GEMINI_API_KEY` default from `lib/core/config/env_config.dart`.
   * Added `lib/services/app_config_service.dart`, which reads the key from the Supabase table `app_config` (cached for 30 minutes, retried after 30 seconds when empty/failed).
   * `GeminiService` now loads the key through `AppConfigService` (`_generate` and `_searchWithGemini`). Without a key (or when the user is not logged in) the app falls back to the `gemini-chat` Edge Function and then the local search / answer engine.
2. **Database Migration:**
   * Added `supabase/migrations/20261030_app_config.sql` (table `app_config`, RLS: authenticated users can read, only admins can write, anon has no access; seeds an empty `GEMINI_API_KEY` row).
3. **Environment configuration:**
   * `EnvConfig` no longer contains the Supabase URL, publishable key or storage URL as defaults. Values come from `.env` via `flutter run --dart-define-from-file=.env`.
   * Added `EnvConfig.assertConfigured()` (called in `main()`), which fails at startup with a clear message when the build was started without the env file.
   * `AppImages.getPublicFallbackUrl` now derives the storage URL from `SUPABASE_URL` instead of a hardcoded project domain.
   * `.env` removed of the Gemini key and added to `.gitignore`; `.env.example` now contains placeholders only.
4. **Versioning:** Bumped app version to `1.1.2-beta+12` (`pubspec.yaml`, `AppConstants.appVersion`).

**Action required after updating:** run `20261030_app_config.sql`, store the new Gemini key in `app_config`, revoke the old key in Google AI Studio (it was present in the repository history), and run `git rm --cached .env` so the local `.env` is no longer tracked.

---

## Version 1.1.0-beta Changelog

1. **POS Cashier Dashboard (`lib/screens/cashier/cashier_dashboard_screen.dart`):**
   * Fixed category filters: chips are now built dynamically from database categories used by the loaded products (previously hard-coded IDs that matched nothing).
   * Added product photos to POS product cards using `AppImages.resolveProductImages`, with a multi-URL fallback chain (`_PosImageChain`) and placeholder icon.
   * Cleaned `unnecessary_underscores` lint notices in the new image code.
2. **Cart (`lib/providers/cart_provider.dart`):**
   * Cart item images are now resolved through `AppImages.resolveProductImages` when the cart is restored from cache/database, so photos still appear after the app is closed and reopened.
3. **Notifications:**
   * Removed the four hard-coded demo notifications that appeared on every login.
   * Notifications are now stored per user: local cache in `SharedPreferences` (key `user_notifications_<userId>`) plus cross-device sync with the new Supabase table `user_notifications` (RLS: each user can only read/insert/update/delete their own rows).
   * `NotificationProvider` is now a `ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>` in `lib/main.dart` and loads/clears notifications when the user logs in, logs out, or switches account.
   * Added `toMap` / `fromMap` to `AppNotificationModel`.
   * Notification sources: successful checkout (order), PC Quiz / Memory Match / Speed Repair completion (minigame), and the manual "Simpan Peringatan" button in the bottleneck calculator when bottleneck is above 15%.
4. **Database Migration:**
   * Added `supabase/migrations/20261029_user_notifications.sql` (table, index, RLS policies).
5. **Versioning:** Bumped app version to `1.1.0-beta+10` (`pubspec.yaml`, `AppConstants.appVersion`).

---

## Version 1.0.9-beta Changelog

1. **Order Management for Cashiers & Admins:**
   * Added a `Pesanan` tab to the cashier dashboard (search, channel filter, status update).
   * Added a shared order update dialog with courier and tracking number (resi) input; resi is mandatory for `shipped` online orders.
   * Added the `update_order_tracking` RPC (`20261027_order_tracking_number.sql`), restricted to staff.
2. **Order Tracking (Customer):**
   * Removed the auto-generated demo resi; the tracking screen shows the resi entered by staff and allows copying it, or "Belum tersedia" with the copy button disabled.
3. **POS Checkout Fix:**
   * Dropped the duplicate legacy `create_pos_order(varchar, numeric, varchar, jsonb)` overload that caused PGRST203 (`20261028_drop_old_create_pos_order.sql`).
4. **Stock Handling & Storefront UI:**
   * Out-of-stock products can no longer be added to the cart; the product detail button becomes "Stok Habis" and cart quantities are capped at available stock.
   * Product cards now show a stock badge (green / yellow for 5 or fewer / red "Stok Habis").
   * Cart summary (coupon, subtotal, shipping estimate, total, checkout) is now a compact panel docked directly above the bottom navigation bar, and the duplicated bottom spacing was removed.
5. **Versioning:** Bumped app version to `1.0.9-beta+9`.

---

## Version 1.0.8-beta Changelog

1. **Point of Sale (POS) & Cashier Dashboard:**
   * Created `CashierDashboardScreen` with Mesin Kasir POS, Shift Management, Store Transactions, and Stock Checker.
   * Integrated `create_pos_order` RPC with auto-inventory deduction, change calculator, and digital receipts.
   * Added Shift opening, closing, and automatic cash variance reconciliation.
2. **Loyalty Points Hardening:**
   * Customer points and membership tiers are protected from client updates.
   * Delivered online orders award points once on the server; unverified minigame rewards are disabled.
3. **Omnichannel Order & Admin Analytics:**
   * Order channel classification (`online` vs `pos`) and filtering chips in admin dashboard.
   * Omnichannel revenue breakdown and real-time cashier shift monitoring in admin stats tab.
   * Staff provisioning dialog calling the authenticated `provision-staff` Edge Function.
4. **Database Migration Scripts:**
   * Added `supabase/migrations/20261024_harden_client_access.sql` for strict order/shift RLS, profile creation, and server-calculated transactions.
   * Updated `supabase/migrations/add_admin_features.sql` with relaxed column guards.
5. **Code Health & Quality Assurance:**
   * `flutter analyze lib` currently reports no errors; remaining informational lint notices should be resolved before claiming a clean analysis.

---

## Database Schema & Migration Reference

To synchronize a remote Supabase database, run the scripts in this order in the Supabase SQL Editor:

1. `supabase/migrations/add_admin_features.sql` (role helpers, user/profile RLS, review and product policy support).
2. `supabase/migrations/add_orders_warranty_and_items.sql` (warranty columns and order items).
3. `supabase/migrations/20261024_harden_client_access.sql` (strict RLS, profile trigger, atomic order/stock RPCs, and cashier shifts).
4. `supabase/migrations/20261024_seed_product_categories.sql` (seed product categories referenced by the product foreign key).
5. `supabase/migrations/20261024_product_image_storage.sql` (public product image delivery and staff-only image upload/update/delete policies).
6. `supabase/migrations/20261025_flash_sales_sync.sql` (flash sale timers stored in `flash_sales`).
7. `supabase/migrations/20261026_member_exp_blockchain.sql` (member EXP ledger; replaces `update_order_status`).
8. `supabase/migrations/20261027_order_tracking_number.sql` (staff-only `update_order_tracking` RPC for courier and resi).
9. `supabase/migrations/20261028_drop_old_create_pos_order.sql` (removes the legacy duplicate `create_pos_order` overload; only needed if both overloads exist in your database).
10. `supabase/migrations/20261029_user_notifications.sql` (per-user notification table with RLS for cross-device sync).

11. `supabase/migrations/20261030_app_config.sql` (`app_config` table with RLS; store the Gemini API key here instead of in the app).
12. `supabase/migrations/20261031_fix_product_subtype_fk.sql` (normalizes `subtype`/`brand_code` so adding a product no longer violates `fk_products_subtype`).
13. `supabase/migrations/20261031_biometric_login.sql` (`user_biometrics` / `user_security_settings` with own-row RLS for fingerprint login).
14. `supabase/migrations/20261101_product_reviews.sql` (per-item reviews with photo/video, rating trigger, `submit_product_review` RPC, `review-media` bucket).

The older `fix_cashier_shifts_rls.sql` is retained only for compatibility; do not use it instead of the hardening migration. Do not expose or recreate the removed demo administrator credentials. Reset any staff credentials previously published in project documentation.

Deploy the two Edge Functions and configure their secrets:

```bash
supabase functions deploy gemini-chat
supabase functions deploy provision-staff
supabase secrets set GEMINI_API_KEY=YOUR_GEMINI_KEY
```

The Edge Function secret above is only needed for the server-side fallback. The in-app Gemini calls use the key stored in the database:

```sql
UPDATE public.app_config SET value = 'YOUR_GEMINI_KEY' WHERE key = 'GEMINI_API_KEY';
```

`provision-staff` also requires the Supabase service-role secret in the Edge Function environment. Never place the service-role secret in Flutter assets or `--dart-define` values. Public app configuration (Supabase URL, publishable key, storage URL) is not hardcoded; it is supplied at build time from `.env`:

```bash
cp .env.example .env   # fill in your Supabase values
flutter run --dart-define-from-file=.env
```

The Gemini API key is not part of `.env`; it lives in the `app_config` table.

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

2. Create your local environment file (it is git-ignored):
   ```bash
   cp .env.example .env
   ```
   Fill in `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_STORAGE_URL`.

3. Install dependencies:
   ```bash
   flutter pub get
   ```

4. Run static code analysis:
   ```bash
   flutter analyze lib
   ```

5. Launch target application:
   ```bash
   flutter run --dart-define-from-file=.env
   ```

6. Build a release APK (the env file is required, otherwise the app stops at startup):
   ```bash
   flutter build apk --release --dart-define-from-file=.env
   ```
   Output: `build/app/outputs/flutter-apk/app-release.apk`.
