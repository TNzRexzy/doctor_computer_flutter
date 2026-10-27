# Changelog

Notable changes to Doctor Computer are documented here.

## Unreleased

### Added

- Added offline authentication for Admin and Cashier accounts that have signed in online on the same device. A salted PBKDF2-HMAC-SHA256 password verifier and minimal profile metadata are stored in secure storage; offline credentials expire after 14 days.
- Added a versioned SQLite database for product and category catalog caching, Admin dashboard snapshots, POS orders and order items, and cashier shifts.
- Added atomic, local-first persistence for cashier shifts and POS checkout, including local stock reservations while transactions are pending synchronization.
- Added an Admin synchronization outbox for supported product, flash-sale, voucher, user-profile, and order status/tracking changes. Failed synchronization attempts remain pending with their error recorded.
- Added connectivity-aware synchronization that requires a valid online staff session, refreshes catalog and Admin snapshots, processes Admin edits, synchronizes shifts before POS orders, and closes shifts after their orders have synchronized.
- Added idempotent Supabase RPCs and local-to-remote ID mappings for POS shift and order synchronization.
- Added offline product editing flows that use cached categories and allow product changes without attempting an image upload.
- Added SQLite tests for atomic POS order persistence, pending stock reservations, preservation of pending Admin edits, and local order status updates.

### Changed

- Updated the Admin dashboard to display locally cached products, orders, users, vouchers, and shifts when using an offline staff session or when remote data cannot be loaded.
- Updated the shared order update dialog to queue supported status and tracking edits locally when the staff session is offline or the network is unavailable.
- Updated the README with the offline-first data flow, local storage boundaries, synchronization behavior, and online-only limitations.

### Security and limitations

- Offline authentication is available only to previously authenticated Admin/Cashier accounts, and customer features remain online-only.
- Product image uploads and staff provisioning still require an online connection because they depend on Supabase Storage and the trusted `provision-staff` Edge Function.
- Passwords and image binaries are not stored in the SQLite database or synchronization outbox.
