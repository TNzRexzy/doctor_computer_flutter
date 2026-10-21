-- ============================================================
-- MIGRATION: fix PostgreSQL error 22023 — role "admin" does not exist
-- Run this in the Supabase SQL Editor. Safe to re-run (idempotent).
--
-- Symptom:
--   PostgrestException: role "admin" does not exist (SQLSTATE 22023)
--   thrown while loading cart_items, pc_parts, products, or any other table.
--
-- Root cause:
--   Supabase copies every key of `auth.users.raw_app_meta_data` into the
--   access token as a TOP-LEVEL JWT claim. When an "admin" flag is written
--   there as `role` (instead of a namespaced key such as `app_role`), the
--   token looks like {"role": "admin", ...}. PostgREST trusts that claim and
--   runs `SET LOCAL ROLE "admin"` on every request. PostgreSQL has no
--   database role named `admin`, so it answers with SQLSTATE 22023 and the
--   request dies before RLS is even evaluated.
--
--   The application role must therefore live in `public.users.role` (read by
--   the Flutter app) — never in the `role` key of the auth metadata.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Make sure the application role column exists
-- ------------------------------------------------------------
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS role varchar(20) NOT NULL DEFAULT 'user';

-- ------------------------------------------------------------
-- 2. Strip the leaked `role` key from the auth metadata
--
--    `- 'role'` is a no-op when the key is absent, so this is safe to run
--    repeatedly. Only the top-level JWT claim is affected; the app role is
--    re-read from public.users.role by the Flutter client.
-- ------------------------------------------------------------
UPDATE auth.users
SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb) - 'role'
WHERE raw_app_meta_data ? 'role';

-- ------------------------------------------------------------
-- 3. Promote the store-owner account via the application column
--
--    `public.users.id` holds the auth user id as text. The upsert also
--    covers the case where the profile row was never created, so the account
--    is recognised as admin on its next login.
-- ------------------------------------------------------------
-- The insert is guarded instead of using ON CONFLICT: the profile row may
-- conflict on `id` *or* on the unique `email` column, and a raised unique
-- violation would abort the rest of this script.
INSERT INTO public.users (
  id,
  full_name,
  email,
  phone,
  address,
  city,
  membership_tier,
  points,
  join_date,
  role
)
SELECT
  u.id::text,
  COALESCE(NULLIF(u.raw_user_meta_data->>'full_name', ''), split_part(u.email, '@', 1)),
  lower(u.email),
  '',
  '',
  '',
  'platinum',
  0,
  COALESCE(u.created_at, now()),
  'admin'
FROM auth.users u
WHERE lower(u.email) = 'nopal48@gmail.com'
  AND NOT EXISTS (
    SELECT 1
    FROM public.users p
    WHERE p.id = u.id::text OR lower(p.email) = 'nopal48@gmail.com'
  );

-- Promote every existing profile row for the owner account, including
-- duplicates left behind by an earlier retried registration.
UPDATE public.users
SET role = 'admin'
WHERE lower(email) = 'nopal48@gmail.com';

-- ------------------------------------------------------------
-- 4. Store the admin flag in a namespaced custom claim as well
--
--    `app_role` cannot collide with a reserved JWT claim, so PostgREST keeps
--    switching into the `authenticated` database role.
-- ------------------------------------------------------------
UPDATE auth.users
SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb)
  || jsonb_build_object('app_role', 'admin')
WHERE lower(email) = 'nopal48@gmail.com';

-- ------------------------------------------------------------
-- 5. Verification
--    Expected: zero rows left with a top-level `role` claim, and
--    nopal48@gmail.com listed as admin.
-- ------------------------------------------------------------
SELECT
  'leaked_role_claims' AS check,
  count(*) AS rows_affected
FROM auth.users
WHERE raw_app_meta_data ? 'role';

SELECT id, email, role
FROM public.users
WHERE lower(email) = 'nopal48@gmail.com';
