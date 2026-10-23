# Doctor Computer Application

Production-ready cross-platform computer retail and interactive PC configurator system built with Flutter, Provider architecture, Supabase backend integration, OpenStreetMap geospatial services, and Google Gemini AI.

- **Application Name:** Doctor Computer
- **Release Version:** 1.0.10-beta
- **Target Platforms:** Android, iOS, Windows, Web
- **Engine:** Flutter 3.47+ / Dart 3.13+

---

## Technical Architecture Overview

Doctor Computer utilizes a decoupled, reactive architecture adhering to clean Flutter development principles:

- **Presentation Layer:** Declarative UI widgets with reactive state listeners via `Provider` pattern.
- **State Management:** Scoped `ChangeNotifier` providers (`AuthProvider`, `CartProvider`, `ProductProvider`, `PcBuilderProvider`, `OrderProvider`, `BlockchainProvider`, `WishlistProvider`, `NotificationProvider`, `ThemeProvider`).
- **Data Layer & Remote Persistence:** Supabase PostgreSQL with PostgREST API client, row-level security resilience, and local caching fallback via `SharedPreferences`.
- **Geospatial & Mapping Engine:** OpenStreetMap tile integration via `flutter_map` with real-time reverse geocoding through Nominatim HTTP endpoints.
- **Artificial Intelligence Engine:** Context-aware assistant and heuristic search algorithms integrated with Google Gemini API runtime database loaders.

---

## Role-Based Access Control (RBAC) Specification

The system implements strict role-based authorization to divide administrative functions from customer-facing interfaces.

### Built-in Verification Accounts

| Role               | Username / Identity                      | Credential                       | Authorization Scope                                                                                                                                                                                                                                 |
| ------------------ | ---------------------------------------- | -------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Administrator      | `admin` or `admin@doctorcomputer.id`     | `admin123` / `Admin@DC2026!`     | Full administrative dashboard access; modify product stock and catalog pricing; update order fulfillment statuses; manage customer records (arbitrary points/EXP modification, tier reassignment, role elevation); store sales performance metrics. |
| Cashier            | `cashier` or `cashier@doctorcomputer.id` | `cashier123` / `Cashier@DC2026!` | Dedicated cashier panel; inventory stock level adjustments; order dispatch and fulfillment status updates.                                                                                                                                          |
| Customer (Default) | Standard registration flow               | User defined                     | Product browsing, custom PC assembly configurator, checkout and order placement, interactive delivery location selection, warranty tracking, AI consultation, loyalty EXP accrual.                                                                  |

_Note: All newly registered accounts default automatically to the Customer (`user`) role._

---

## Major Changes & Implementations

### 1. Geospatial Map Address Picker & Database Synchronization

- **Interactive Map Integration:** Implemented `LocationPickerScreen` using OpenStreetMap raster tiles through `flutter_map` (v8.3+) and `latlong2`. Users can drag, pan, zoom, and pinpoint precise coordinates on the map.
- **Reverse Geocoding Engine:** Coordinate changes trigger asynchronous queries to the Nominatim reverse geocoding API, extracting street names, urban districts, postal codes, and city jurisdictions.
- **Address Search & Quick Presets:** Integrated text query search for Indonesian regions alongside quick-navigation shortcuts for major metropolitan areas (Jakarta Pusat, Jakarta Selatan, Bandung, Surabaya, Yogyakarta, Medan).
- **Database Persistence:** Confirmed location results automatically update the logged-in user profile in Supabase (`latitude`, `longitude`, `address`, `city`).
- **Checkout & Profile Interoperability:** Both checkout and profile forms pre-populate from stored database coordinates, eliminating duplicate address entry.

### 2. Administrative Operations & Management Dashboard

- **Dynamic Role Dashboard Routing:** Implemented `AdminDashboardScreen` supporting tabbed operations for inventory, transactions, user administration, and key metrics.
- **Stock & Pricing Management:** Real-time modal editor allowing administrators and cashiers to adjust catalog inventory counts and unit pricing with direct database updates.
- **Fulfillment Pipeline:** Status transition handling (`Processing`, `Shipped`, `Delivered`, `Cancelled`) with synchronized state persistence in remote transaction records.
- **User Management & Gamification Control:** Administrative capabilities to inspect user accounts, reassign membership tiers (`Bronze`, `Silver`, `Gold`, `Platinum`), and manually adjust reward EXP/points balances.
- **Analytical Overview:** Real-time calculation of gross revenue, active inventory volume, total order count, and low-stock warning indicators.

### 3. Artificial Intelligence Engine & Semantic Search Refactoring

- **Context-Aware Customer Support:** Overhauled `GeminiService` customer support module to eliminate hardcoded response templates, introducing dynamic heuristic matching and runtime API key retrieval from the Supabase `app_settings` table.
- **Category-Prioritized Smart Search:** Refactored search index matching to enforce category exclusivity before textual relevance (e.g., queries for "SSD" isolate components under storage classifications rather than laptops containing SSD spec mentions).
- **Deterministic Bottleneck & FPS Calculator:** Deployed an 8-game benchmark evaluation database across 10 hardware performance tiers (Cyberpunk 2077, Red Dead Redemption 2, Valorant, GTA V, Black Myth: Wukong, Forza Horizon 5, Counter-Strike 2) with color-coded performance thresholds (Green: >=60 FPS, Yellow: 30-59 FPS, Red: <30 FPS).

### 4. End-to-End PC Builder Cart Integration

- Connected interactive PC configurator selections directly to `CartProvider`.
- Every selected hardware component (CPU, GPU, Motherboard, RAM, Storage, PSU, Case, Cooler) is normalized into a `ProductModel` instance with associated assembly service line items (Standard or Premium assembly tier) and transferred to the checkout pipeline.

### 5. Checkout Navigation & Route History Stabilization

- Resolved critical blank screen defect post-purchase.
- Normalized all `MaterialPageRoute` declarations within `AppRouter` to preserve route settings metadata (`settings: settings`).
- Post-checkout confirmation now triggers a clean stack purge via `pushNamedAndRemoveUntil(context, AppRouter.mainNav, (route) => false)` followed immediately by `AppRouter.orderHistory`, displaying the newly generated Order ID and transaction summary.

### 6. Dual-Mode Catalog Presentation

- Added layout toggle capability to `CatalogScreen`, supporting switching between dense multi-column Grid View and comprehensive List View with detailed component specifications.

### 7. Profile Picture Database Synchronization

- Enabled profile image modification via remote URL dialog, persisting image references directly into the `profile_image_url` field of the Supabase user schema.

### 8. Dynamic Membership Synchronization & Admin Full-Privilege State

- **Cross-Screen Progress Synchronization:** Unified loyalty progress calculations between `ProfileScreen` and `MemberScreen` via `BlockchainProvider`. The progress bar dynamically visualizes true fractional distance between tiers (`((totalExp - currentTier.value) / (nextTier.value - currentTier.value))`).
- **Administrator Max Status:** Accounts authenticated with the `admin` role are assigned maximum parameters: Platinum Tier (`0xFFE5E4E2`), 999,999 EXP, full progress visualization (1.0), and full access badges across all profile and membership views.

---

## Minor Changes & System Optimizations

1. **User Interface Language Standardization:** Removed all composite bilingual strings (e.g., "Masuk / Login", "Alamat / Address", "Cari / Search") across 15+ screens in favor of clean, consistent Indonesian terminology.
2. **Database Query Coercion Hardening:** Replaced fragile `.single()` and `.maybeSingle()` PostgREST invocations with deterministic `.limit(1)` queries in `AuthProvider`, resolving runtime exceptions (`PostgrestException: Cannot coerce the result to a single JSON object`) caused by duplicate records.
3. **Database Schema Fallback Handling:** Implemented defensive schema mapping to gracefully handle environments where new columns (`role`, `profile_image_url`, `latitude`, `longitude`) are pending migration, preventing `PGRST204` crashes during registration.
4. **Registration Error Handling:** Enhanced authentication exception handling to intercept HTTP 422 errors and display clear duplicate account notices.
5. **Flexible Authentication Input:** Extended the login credential validator to accept identity aliases (`admin`, `cashier`) alongside standard email formats.
6. **Application Version Metadata:** Synchronized application build metadata across dialogs, constants, and `pubspec.yaml` to display `Beta v1.0.8-beta`.
7. **Code Analysis & Lint Compliance:** Eliminated unused imports, corrected 8-digit hexadecimal color values, and resolved asynchronous context gap warnings. The codebase passes `flutter analyze` with 0 issues.

---

## Issue Resolution Matrix

| Defect ID | Description                                                                                                         | Root Cause                                                                                                                                                       | Status                                                                                                                        |
| --------- | ------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| BUG-001   | Google and Apple authentication buttons unresponsive                                                                | Handler callbacks were unassigned empty closures                                                                                                                 | Resolved (Informational modal and notification dispatched)                                                                    |
| BUG-002   | Home screen PC Builder button hides navigation bar and triggers unprompted theme switch                             | Button invoked `Navigator.pushNamed` instead of delegating to parent `MainNavScreen` tab index                                                                   | Resolved (Switches tab index via `MainNavScreenState.switchToTab(2)`)                                                         |
| BUG-003   | AI Customer Support responses strictly templated                                                                    | Absence of API key loading and rudimentary fallback logic                                                                                                        | Resolved (Runtime Supabase key loader and contextual heuristic engine deployed)                                               |
| BUG-004   | PC Builder selections do not persist to shopping cart                                                               | Confirmation dialog lacked execution calls to `CartProvider`                                                                                                     | Resolved (Component normalization and service fee dispatch implemented)                                                       |
| BUG-005   | Post-purchase blank screen                                                                                          | `Navigator.popUntil` failed to identify route due to missing `RouteSettings` in router                                                                           | Resolved (RouteSettings attached across router; deterministic navigation to order history deployed)                           |
| BUG-006   | AI Smart Search category pollution                                                                                  | Query algorithm evaluated textual description tokens before category categorization                                                                              | Resolved (Category-first isolation implemented)                                                                               |
| BUG-007   | Database schema cache error on register (PGRST204)                                                                  | Insert query passed uncommitted schema columns                                                                                                                   | Resolved (Standardized core schema insert with fallback role resolution)                                                      |
| BUG-008   | PostgREST single object coercion failure on login                                                                   | Multiple matching rows triggered coercion exceptions on `.single()`                                                                                              | Resolved (Transitioned to `.limit(1)` query format)                                                                           |
| BUG-009   | Admin user editing does not persist to database                                                                     | Supabase RLS blocks cross-user updates; no `role` column in schema                                                                                               | Resolved (Dual persistence with SharedPreferences cache + RLS policy migration)                                               |
| BUG-010   | Blank white screen upon triggering Flash Sale dialog                                                                | Unbounded layout constraints on Slider in dialog and type cast exceptions on numeric price strings                                                               | Resolved (Replaced dialog with constrained modal bottom sheet, bounded box layout, and defensive numeric parsing)             |
| BUG-011   | App stuck before splash screen (runApp never reached)                                                               | `AuthProvider` constructor called `restoreSession()` fire-and-forget while `main()` awaited it again, causing a race condition on Supabase and SharedPreferences | Resolved (Removed duplicate `restoreSession()` call from constructor)                                                         |
| BUG-012   | Undefined identifier `user` in admin dashboard                                                                      | `user` variable referenced in admin blockchain sync was never declared in scope                                                                                  | Resolved (Replaced with `context.read<AuthProvider>().currentUser`)                                                           |
| BUG-013   | `use_build_context_synchronously` warning in admin dashboard                                                        | `context.read<BlockchainProvider>()` called after async gap without mounted check                                                                                | Resolved (Added `if (!ctx.mounted) return;` guard before async context usage)                                                 |
| BUG-014   | `invalid_constant` error in product detail screen                                                                   | `const Icon` used with non-const `AppColors.error` color value                                                                                                   | Resolved (Removed `const` keyword from Icon constructor)                                                                      |
| BUG-015   | Cart upsert fails on `cart_items` table                                                                             | `.upsert(onConflict: 'user_id,product_id')` assumed a unique constraint that does not exist on the table                                                         | Resolved (Replaced with select-then-insert/update logic)                                                                      |
| BUG-016   | Review insert crashes with schema mismatch                                                                          | `toMap()` included `media_urls` field not present in `reviews` table schema                                                                                      | Resolved (Created separate `toSupabaseMap()` that excludes non-DB fields)                                                     |
| BUG-017   | Order items FK violation for PC build parts                                                                         | Cart items with `build-` prefixed IDs reference non-existent products table rows                                                                                 | Resolved (Added FK guard `!product.id.startsWith('build-')` in cart and order providers)                                      |
| BUG-018   | Notification screen dependent on hardcoded mock data                                                                | `NotificationProvider` returned static mock notifications unrelated to actual user activity                                                                      | Resolved (Rewrote to generate notifications dynamically from orders, products, and user data)                                 |
| BUG-019   | Membership screen shows hardcoded tier data                                                                         | Tier thresholds, discounts, and benefits were static constants instead of DB-driven                                                                              | Resolved (Reads dynamically from `membership_tiers` table with local fallback)                                                |
| BUG-020   | PC builds not persisted to database                                                                                 | PC Builder confirmation only added items to cart without saving the build configuration                                                                          | Resolved (Saves complete build record to `pc_builds` table via `toSupabaseMap()`)                                             |
| BUG-021   | Fingerprint button on the login screen signs in as a previously enrolled account (e.g. Admin) after switching users | Single global `saved_biometric_user` slot that was never cleared, plus fallbacks to `last_known_user` / `cached_active_user`                                     | Resolved (Per-account enrollment; button follows the last logged-in account and is hidden if that account has no fingerprint) |
| BUG-022   | Biometric enrollment remained after biometrics were disabled or the last fingerprint was deleted                    | `setBiometricEnabled(false)` and `deleteBiometricCredential` never cleared the stored account                                                                    | Resolved (Enrollment of that account is removed from secure storage and preferences)                                          |
| BUG-023   | Biometric login produced no Supabase session and trusted the role from local JSON                                   | Session was rebuilt from cached profile instead of re-authenticating                                                                                             | Resolved (Credentials from secure storage are used to call `login()` again; role comes from the database)                     |

---

## Version 1.0.10-beta Changelog (Biometric Authentication Security Fix)

### Security Fixes

1. **Biometric Login Bound to a Real Session:** Biometric sign-in no longer restores the session from a cached profile JSON in `SharedPreferences`. The stored credentials of the enrolled account are read from secure storage and `AuthProvider.login()` is called again, so a genuine Supabase Auth session is created and the user role always comes from the database instead of local, editable data.
2. **Removed Unsafe Account Fallbacks:** `loginWithBiometrics()` and `getBiometricEnrolledUserName()` no longer fall back to `last_known_user` or `cached_active_user`. Biometric login can no longer sign in as "whoever used the phone last" when no fingerprint was enrolled.
3. **Removed Always-Pass Credential Check:** Deleted the `hasType = true` fallback that made the `user_biometrics` verification always succeed. A fingerprint must now exist in `user_biometrics` (database, then local cache) for the signed-in account, otherwise the session is closed and the enrollment is cleared.
4. **Password Verification Before Enrollment:** Registering a fingerprint, or re-enabling biometric login, now requires the account password (verified with `AuthProvider.verifyCurrentPassword`) before the hardware sensor prompt is shown. This prevents someone with access to an unlocked session from enrolling their own fingerprint.
5. **Encrypted Credential Storage:** Account email and password used for biometric re-login are stored with `flutter_secure_storage` (Android Keystore / iOS Keychain), keyed per user. Plain profile data and roles are no longer persisted for biometric purposes.

### Bug Fixes

1. **Wrong Account on the Login Screen (BUG-021):** The fingerprint button used a single global slot (`saved_biometric_user`) that was never cleared, so it kept signing in as the previously enrolled account (for example Admin) after switching to another user. The button now follows the account that logged in last on the device and appears only if that account has an enrolled fingerprint.
2. **Stale Enrollment After Disable or Delete (BUG-022):** Turning biometrics off or deleting the last fingerprint did not remove the enrolled account from the device. It now removes the enrollment of that account only; other accounts on the device are untouched.
3. **Missing Supabase Session After Biometric Login (BUG-023):** After `logout()` called `supabase.auth.signOut()`, biometric login left `currentUser` null on the Supabase client, which breaks any RLS-protected call. Resolved by the re-login flow described above.

### Changes

1. **Per-Account Biometric Enrollment:** One device can hold biometric enrollments for several accounts. Enrollment data lives in the new `lib/services/biometric_credential_store.dart`.
2. **Login Screen:** The fingerprint button is hidden when there is nothing to sign in with. When visible it shows `Sidik jari: {nama akun}` and a `Hapus dari HP ini` action that removes that account's enrollment from the device.
3. **Self-Healing Enrollment:** If the saved password no longer works (for example it was changed elsewhere) or credentials are missing, the enrollment is cleaned up and the user is asked to sign in with a password and register the fingerprint again.
4. **Legacy Data Handling:** The old `saved_biometric_user` slot is migrated to the new account list. Because earlier versions did not store credentials in secure storage, such entries are discarded and each user must register their fingerprint once more.
5. **Cleanup:** `last_known_user` is no longer written and is removed on logout. Admin and cashier fallback credential checks were centralized into `_isFallbackAdmin` and `_isFallbackCashier`.
6. **New Dependency and Android Setting:** Added `flutter_secure_storage`; set `android:allowBackup="false"` to avoid Keystore unwrap errors after backup restore.

### Known Limitation

`local_auth` accepts any fingerprint enrolled in the phone's system settings, so the biometric check proves device-level identity, not application-level identity. For stronger protection of Admin and Cashier accounts, consider `biometric_storage` or an additional PIN for those roles.

---

## Version 1.0.8-beta Changelog

### New Features

1. **Full Database Schema Synchronization:** Aligned all Flutter models and providers with the latest PostgreSQL schema — added `sku`, `brand_code`, and `subtype` fields to `ProductModel` and `PcPartModel`; created new `BrandModel` and `ProductSubtypeModel` for the `brands` and `product_subtypes` lookup tables.
2. **100% Database-Driven Data:** Removed the entire `lib/data/mock/` directory (`mock_categories.dart`, `mock_products.dart`, `mock_pc_parts.dart`). All product, category, and PC part data is now sourced exclusively from Supabase.
3. **Dynamic Notification System:** Rewrote `NotificationProvider` to generate notifications from real database activity (recent orders, new products, membership changes) instead of static mock data. Registered as `ChangeNotifierProxyProvider` keyed to the authenticated user ID.
4. **Sticky Pinned Search Bar:** Home dashboard search bar remains fixed at the top of the screen when scrolling, ensuring product search is always accessible.
5. **Draggable Floating AI Assistant:** Replaced the static bottom-bar AI button with a draggable floating action button ("Tanya Dokter AI") that can be repositioned anywhere on screen.
6. **Database-Driven Membership Tiers:** `MembershipScreen` now reads tier definitions (thresholds, discounts, benefits) from the `membership_tiers` table with graceful local fallback.
7. **PC Build Persistence:** Complete PC build configurations (CPU, GPU, motherboard, RAM, storage, PSU, case, cooler, service tier, pricing) are saved to the `pc_builds` table.
8. **Migration SQL Script:** Added `supabase/migrations/20261022_schema_sync_latest.sql` to provision `brands`, `product_subtypes`, and all new columns.

### Bug Fixes

1. **Cart Upsert Fix (BUG-015):** Replaced broken `.upsert(onConflict:)` with select-then-insert/update pattern since `cart_items` lacks a unique constraint on `(user_id, product_id)`.
2. **Review Schema Fix (BUG-016):** Created `toSupabaseMap()` for `ReviewModel` that excludes client-only fields (`media_urls`) not present in the database schema.
3. **Order Items FK Guard (BUG-017):** Added guard to skip `build-` prefixed product IDs when inserting order items to prevent foreign key violations.
4. **Notification Mock Removal (BUG-018):** Eliminated all hardcoded notification data; notifications are now generated from real order/product/user activity.
5. **Membership Data Fix (BUG-019):** Tier definitions are now fetched from `membership_tiers` table instead of hardcoded constants.
6. **PC Build Persistence Fix (BUG-020):** Build configurations are now properly saved to the `pc_builds` table on confirmation.

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

## Version 1.0.8-beta Changelog (Supabase Production Database & Blockchain Integration)

1. **Sinkronisasi Katalog Produk & Komponen PC (`products` & `pc_parts`):**
   - Menambahkan dukungan atribut skema terbaru: `sku`, `brand_code`, dan `subtype` pada `ProductModel` dan `PcPartModel`.
   - Mengintegrasikan mapping serialisasi (`toMap`, `fromMap`, `copyWith`) pada seluruh alur katalog, admin CRUD, SharedPreferences cache, dan PostgREST remote persistence.
2. **Arsitektur Relasional Pesanan (`orders` & `order_items`):**
   - Menyelaraskan tabel `orders` dengan kolom schema database: `id`, `user_id`, `total_price`, `status`, `order_date`, `shipping_address`, `payment_method`, `created_at`, `updated_at`.
   - Menghubungkan penyimpanan detail barang belanjaan secara langsung ke tabel relasi `order_items` (`id`, `order_id`, `product_id`, `quantity`, `unit_price`).
   - Saat memuat pesanan dari Supabase, item direkonstruksi melalui query ke `order_items` dan digabungkan secara transparan ke `OrderModel`.
   - Fitur penilaian/ulasan pesanan lokal dan serial garansi dipertahankan dengan mekanisme caching offline-first SharedPreferences tanpa menimbulkan kegagalan PostgREST.
3. **Persistensi Rakitan PC (`pc_builds`):**
   - Menambahkan pemetaan lengkap pada `PcBuildModel` untuk tabel `pc_builds`, mencakup relasi foreign key per komponen (`cpu_id`, `gpu_id`, `motherboard_id`, `ram_id`, `storage_id`, `psu_id`, `case_id`, `cooler_id`), `service_tier`, rincian biaya (`total_parts_price`, `build_fee`, `grand_total`), serta flag `is_complete`.
   - Mengimplementasikan method `saveBuild(userId)` dan `loadBuild(userId)` pada `PcBuilderProvider` untuk menyimpan dan memulihkan rancangan rakitan PC ke/dari Supabase.
4. **Entitas Membership & Kategori (`membership_tiers` & `categories`):**
   - Menambahkan deserializer `fromMap` dan serializer `toMap` pada `MembershipModel` yang selaras dengan `membership_tiers` (`tier`, `name`, `required_points`, `discount_percent`, `benefits`).
   - Menyediakan `CategoryModel.fromMap` dengan parser dinamis icon string ke `IconData` Material UI.
5. **Sanitasi Query Ulasan (`reviews`):**
   - Menambahkan method `toDbMap()` pada `ReviewModel` yang secara presisi hanya menyertakan kolom yang terdefinisi di Supabase (`id`, `user_id`, `product_id`, `rating`, `comment`, `date`, `user_name`, `reply`, `reply_role`, `reply_date`).
   - Menghindari pengiriman kolom non-DB (`media_urls`) ke Supabase sekaligus tetap menjamin penyimpanan media ulasan pada cache lokal.
6. **Master Brand & Subtipe Produk (`brands` & `product_subtypes`):**
   - Menambahkan model `BrandModel` dan `ProductSubtypeModel` untuk mendukung struktur referensi master data produk.
7. **Role-Based Provisioning Penyesuaian Auth:**
   - Memperbarui inisialisasi akun bawaan di `AuthProvider.ensureAdminAccount()` dengan kolom `role` yang secara eksplisit bernilai `'admin'` dan `'cashier'`.
8. **Optimalisasi Konektivitas Database & Stabilisasi Storage Bucket Supabase (`assets`):**
   - **Eliminasi Defek 403 Forbidden:** Memperbaiki konfigurasi `SUPABASE_STORAGE_URL` dari gateway S3 (`/storage/v1/s3`) ke direct public object endpoint (`/storage/v1/object/public`) pada `.env`, `EnvConfig`, dan `AppImages`.
   - **Pemberantasan Masalah Gambar Hilang-Muncul (Flickering):** Menambahkan normalisasi URL dan encoding spasi otomatis di `AppImageView` untuk menghindari loop error-shimmer berulang saat scrolling list.
   - **Pemetaan Gambar Otomatis & Cerdas:** Menyediakan getter `displayImageUrl` pada `ProductModel` serta mekanisme auto-resolving di `ProductModel.fromMap` dan `PcPartModel.fromMap` yang memetakan seluruh kategori perangkat keras ke 11 aset riil yang terverifikasi di bucket Supabase.
   - **Standardisasi Widget:** Mengganti pemanggilan `Image.network` mentah di seluruh layar dengan komponen `AppImageView`.
9. **Integrasi Penuh Blockchain Ledger ke Supabase (`blockchain_blocks`):**
   - **Persistensi Multi-Perangkat:** Buku besar kriptografis blockchain (Genesis, Minigame, Shopping, Admin Adjustment) disinkronkan langsung ke tabel `blockchain_blocks` di Supabase dengan strategi offline-first cache SharedPreferences.
   - **Pemetaan Snake_case & CamelCase:** Menyediakan `toDbMap(userId)` dan `fromDbMap()` pada `Block` yang kompatibel dengan kolom database Supabase.
   - **Pull-to-Refresh Ledger Screen:** Menambahkan `RefreshIndicator` pada `BlockchainLedgerScreen` agar pengguna dapat memverifikasi dan menyegarkan rantai blok langsung dari cloud.
   - **Pencegahan Duplikasi:** Menggunakan constraint `UNIQUE(user_id, block_index)` dan operasi `upsert` pada `BlockchainProvider._syncBlockToDb`.

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

- **Native Social Authentication:** Implementation of native OAuth SDKs for Google Sign-In and Sign in with Apple.
- **Dynamic Multi-Language Switcher:** Infrastructure for runtime locale switching between Indonesian, English, and Japanese.
- **Automated Payment Gateway:** Integration with external payment gateway sandbox environments (Midtrans Snap / Xendit) to replace the current simulation pipeline.

---

## Database Schema Reference (Supabase Production)

Skema database PostgreSQL Supabase terkini yang diintegrasikan secara penuh pada Doctor Computer:

```sql
-- 1. Tingkatan Member
CREATE TABLE public.membership_tiers (
  tier character varying NOT NULL,
  name character varying NOT NULL,
  required_points integer NOT NULL DEFAULT 0,
  discount_percent numeric NOT NULL DEFAULT 0.00,
  benefits ARRAY NOT NULL DEFAULT '{}'::text[],
  CONSTRAINT membership_tiers_pkey PRIMARY KEY (tier)
);

-- 2. Kategori Produk
CREATE TABLE public.categories (
  id character varying NOT NULL,
  name character varying NOT NULL,
  name_id character varying,
  icon character varying NOT NULL,
  product_count integer NOT NULL DEFAULT 0,
  CONSTRAINT categories_pkey PRIMARY KEY (id)
);

-- 3. Katalog Produk
CREATE TABLE public.products (
  id character varying NOT NULL,
  name character varying NOT NULL,
  description text NOT NULL,
  description_id text,
  price numeric NOT NULL,
  original_price numeric,
  category_id character varying,
  brand character varying NOT NULL,
  image_url ARRAY,
  specs jsonb NOT NULL DEFAULT '{}'::jsonb,
  rating numeric NOT NULL DEFAULT 0.00,
  review_count integer NOT NULL DEFAULT 0,
  stock integer NOT NULL DEFAULT 0,
  is_new boolean NOT NULL DEFAULT false,
  is_on_sale boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone,
  sku character varying,
  brand_code character varying,
  subtype character varying,
  CONSTRAINT products_pkey PRIMARY KEY (id),
  CONSTRAINT products_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id)
);

-- 4. Pengguna & Autentikasi
CREATE TABLE public.users (
  id character varying NOT NULL,
  full_name character varying NOT NULL,
  email character varying NOT NULL UNIQUE,
  phone character varying,
  avatar_url character varying,
  address text,
  city character varying,
  membership_tier character varying NOT NULL DEFAULT 'bronze'::character varying,
  points integer NOT NULL DEFAULT 0,
  join_date timestamp with time zone NOT NULL DEFAULT now(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone,
  role text DEFAULT 'user'::text,
  profile_image_url text,
  latitude double precision,
  longitude double precision,
  CONSTRAINT users_pkey PRIMARY KEY (id)
);

-- 5. Keranjang Belanja
CREATE TABLE public.cart_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id character varying,
  product_id character varying,
  quantity integer NOT NULL DEFAULT 1,
  added_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT cart_items_pkey PRIMARY KEY (id),
  CONSTRAINT cart_items_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT cart_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id)
);

-- 6. Transaksi Pesanan
CREATE TABLE public.orders (
  id character varying NOT NULL,
  user_id character varying,
  total_price numeric NOT NULL,
  status character varying NOT NULL DEFAULT 'processing'::character varying,
  order_date timestamp with time zone NOT NULL DEFAULT now(),
  shipping_address text NOT NULL,
  payment_method character varying NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone,
  CONSTRAINT orders_pkey PRIMARY KEY (id),
  CONSTRAINT orders_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

-- 7. Detail Item Pesanan (Relational Order Items)
CREATE TABLE public.order_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  order_id character varying,
  product_id character varying,
  quantity integer NOT NULL DEFAULT 1,
  unit_price numeric NOT NULL,
  CONSTRAINT order_items_pkey PRIMARY KEY (id),
  CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id),
  CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id)
);

-- 8. Wishlist
CREATE TABLE public.wishlist (
  user_id character varying NOT NULL,
  product_id character varying NOT NULL,
  added_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT wishlist_pkey PRIMARY KEY (user_id, product_id),
  CONSTRAINT wishlist_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT wishlist_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id)
);

-- 9. Komponen Rakit PC
CREATE TABLE public.pc_parts (
  id character varying NOT NULL,
  name character varying NOT NULL,
  category character varying NOT NULL,
  brand character varying NOT NULL,
  price numeric NOT NULL,
  specs jsonb NOT NULL DEFAULT '{}'::jsonb,
  image_url character varying,
  compatibility_tags ARRAY NOT NULL DEFAULT '{}'::text[],
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  sku character varying,
  brand_code character varying,
  subtype character varying,
  CONSTRAINT pc_parts_pkey PRIMARY KEY (id)
);

-- 10. Konfigurasi Rakitan PC
CREATE TABLE public.pc_builds (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id character varying,
  cpu_id character varying,
  gpu_id character varying,
  motherboard_id character varying,
  ram_id character varying,
  storage_id character varying,
  psu_id character varying,
  case_id character varying,
  cooler_id character varying,
  service_tier character varying NOT NULL DEFAULT 'standard'::character varying,
  total_parts_price numeric NOT NULL DEFAULT 0.00,
  build_fee numeric NOT NULL DEFAULT 0.00,
  grand_total numeric NOT NULL DEFAULT 0.00,
  is_complete boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone,
  CONSTRAINT pc_builds_pkey PRIMARY KEY (id),
  CONSTRAINT pc_builds_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT pc_builds_cpu_id_fkey FOREIGN KEY (cpu_id) REFERENCES public.pc_parts(id),
  CONSTRAINT pc_builds_gpu_id_fkey FOREIGN KEY (gpu_id) REFERENCES public.pc_parts(id),
  CONSTRAINT pc_builds_motherboard_id_fkey FOREIGN KEY (motherboard_id) REFERENCES public.pc_parts(id),
  CONSTRAINT pc_builds_ram_id_fkey FOREIGN KEY (ram_id) REFERENCES public.pc_parts(id),
  CONSTRAINT pc_builds_storage_id_fkey FOREIGN KEY (storage_id) REFERENCES public.pc_parts(id),
  CONSTRAINT pc_builds_psu_id_fkey FOREIGN KEY (psu_id) REFERENCES public.pc_parts(id),
  CONSTRAINT pc_builds_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.pc_parts(id),
  CONSTRAINT pc_builds_cooler_id_fkey FOREIGN KEY (cooler_id) REFERENCES public.pc_parts(id)
);

-- 11. Ulasan Produk
CREATE TABLE public.reviews (
  id character varying NOT NULL,
  user_id character varying,
  product_id character varying,
  rating numeric NOT NULL,
  comment text NOT NULL,
  date timestamp with time zone NOT NULL DEFAULT now(),
  reply text,
  reply_role character varying,
  reply_date timestamp with time zone,
  user_name character varying,
  CONSTRAINT reviews_pkey PRIMARY KEY (id),
  CONSTRAINT reviews_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT reviews_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id)
);

-- 12. Master Brand & Subtipe Produk
CREATE TABLE public.brands (
  code character varying NOT NULL,
  name character varying NOT NULL,
  CONSTRAINT brands_pkey PRIMARY KEY (code)
);

CREATE TABLE public.product_subtypes (
  code character varying NOT NULL,
  name character varying NOT NULL,
  CONSTRAINT product_subtypes_pkey PRIMARY KEY (code)
);

-- 13. Buku Besar Kriptografis Blockchain (Gamifikasi & Poin EXP)
CREATE TABLE public.blockchain_blocks (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id character varying NOT NULL,
  block_index integer NOT NULL DEFAULT 0,
  block_type character varying NOT NULL DEFAULT 'generic',
  title character varying NOT NULL,
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  previous_hash character varying NOT NULL,
  hash character varying NOT NULL,
  exp_earned integer NOT NULL DEFAULT 0,
  upgrade_tier character varying,
  timestamp bigint NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT blockchain_blocks_pkey PRIMARY KEY (id),
  CONSTRAINT blockchain_blocks_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
  CONSTRAINT blockchain_blocks_user_index_unique UNIQUE (user_id, block_index)
);

CREATE INDEX idx_blockchain_blocks_user_id ON public.blockchain_blocks(user_id);
CREATE INDEX idx_blockchain_blocks_hash ON public.blockchain_blocks(hash);
CREATE INDEX idx_blockchain_blocks_prev_hash ON public.blockchain_blocks(previous_hash);
```

---

## Development Environment & Execution

### Prerequisites

- Flutter SDK (3.24.0 or higher recommended)
- Dart SDK (3.5.0 or higher recommended)
- Active internet connectivity for Supabase and OpenStreetMap services

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

### 4. Advanced Security & Real Biometric Hardware System (v1.0.9-beta)

- **Real Hardware Biometric Authentication:** Terintegrasi langsung dengan sensor fisik sidik jari perangkat melalui `local_auth` (Android `FlutterFragmentActivity` & `USE_BIOMETRIC`/`USE_FINGERPRINT` OS prompt).
- **Biometric Sign-In Quick Access:** Ikon sensor biometrik pada halaman Sign In hanya tampil untuk akun yang terakhir login di perangkat dan sudah mendaftarkan sidik jari. Setelah sidik jari terverifikasi sensor fisik, aplikasi melakukan login ulang dengan kredensial terenkripsi (secure storage) sehingga sesi Supabase asli terbentuk dan role selalu berasal dari database. Pendaftaran sidik jari wajib verifikasi kata sandi.
- **PIN Keamanan 6 Digit:** Proteksi transaksi dan akun menggunakan PIN 6 digit yang di-hash dengan enkripsi **SHA-256** (PIN plaintext tidak pernah disimpan).
- **Payment Security Shield:** Proteksi verifikasi ganda (Biometrik / PIN) wajib sebelum konfirmasi pembayaran dan checkout pesanan.
- **Keamanan Tambahan:** Pengaturan Autentikasi 2 Langkah (2FA Email/SMS), Auto-Lock berjangka (1 s/d 30 menit), dan notifikasi aktivitas login.
- **Database Persistensi Supabase:**
  - Tabel `user_security_settings`: Menyimpan preferensi keamanan, status PIN hash, 2FA, auto-lock, dan proteksi pembayaran.
  - Tabel `user_biometrics`: Menyimpan kredensial sensor terdaftar (`fingerprint`, nama credential, token SHA-256, device model, dan status aktif) dengan integritas Row Level Security (RLS).
