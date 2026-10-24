-- ============================================================
-- MIGRATION: Admin features - role column, review replies, RLS
-- Run this in Supabase SQL Editor. Safe to re-run (idempotent).
--
-- v1.0.8-beta hotfix (BUG-015):
--   * `CREATE POLICY IF NOT EXISTS` is not valid PostgreSQL, so the previous
--     migration aborted half-way and never created the new policies.
--   * Every policy referenced `public.users` from *inside* a policy on
--     `public.users`. PostgreSQL re-applies RLS for that sub-select, raising
--     "infinite recursion detected in policy for relation users" and blocking
--     the admin dashboard from editing any other account.
--   * `auth.uid()` (uuid) was compared to `users.id` (varchar) without a cast,
--     so admin checks failed with a type error.
--   * A user could set `role = 'admin'` on their own row, escalating privileges
--     with the public anon key.
-- ============================================================

-- 1. Add 'role' column to users table
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS role varchar(20) NOT NULL DEFAULT 'user';

-- 2. Add reply columns to reviews table
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS reply text;
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS reply_role varchar(20);
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS reply_date timestamptz;
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS user_name varchar(100);

-- Staff roles must be granted through a trusted server-side provisioning flow;
-- email addresses alone never confer a privileged role.

-- ------------------------------------------------------------
-- 4. Role helpers (RLS-safe)
--
-- SECURITY DEFINER is what breaks the recursion: these functions read the
-- caller's role row once with the privileges of the function owner, so the
-- lookup does not re-enter the `users` policies. They only ever return data
-- derived from the caller's own row, so nothing leaks.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT u.role
  FROM public.users u
  WHERE u.id = auth.uid()::text
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(public.current_user_role() = 'admin', false);
$$;

CREATE OR REPLACE FUNCTION public.is_staff()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(public.current_user_role() IN ('admin', 'cashier'), false);
$$;

-- Guard: only an admin may change privileged columns, so a signed-in customer
-- cannot promote their own account with the public anon key.
CREATE OR REPLACE FUNCTION public.guard_privileged_user_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Session-less contexts (SQL editor, service role) already bypass RLS.
  IF auth.uid() IS NULL OR public.is_admin() THEN
    RETURN NEW;
  END IF;

  -- Cegah pengguna biasa mengubah role (hak akses) sendiri
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION 'Hanya admin yang boleh mengubah role'
      USING ERRCODE = '42501',
            HINT = 'Perubahan ditolak agar pengguna tidak dapat menaikkan hak akses role sendiri.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS users_guard_privileged_columns ON public.users;
CREATE TRIGGER users_guard_privileged_columns
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.guard_privileged_user_columns();

-- ------------------------------------------------------------
-- 5. RLS policies for users (admin user management)
--    Drop-then-create keeps the script idempotent on re-run.
-- ------------------------------------------------------------
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS users_select_self_or_staff ON public.users;
DROP POLICY IF EXISTS users_insert_self_or_admin ON public.users;
DROP POLICY IF EXISTS users_update_self_or_admin ON public.users;
DROP POLICY IF EXISTS users_delete_admin ON public.users;

-- Legacy policy names from earlier releases of this migration.
DROP POLICY IF EXISTS admin_update_users ON public.users;
DROP POLICY IF EXISTS user_update_own ON public.users;
DROP POLICY IF EXISTS admin_read_all_users ON public.users;

-- Read: own row, or every row when the caller is admin/cashier.
CREATE POLICY users_select_self_or_staff ON public.users
  FOR SELECT TO authenticated
  USING (id = auth.uid()::text OR public.is_staff());

-- Insert: the caller's own profile row (registration / login bootstrap), or
-- any row when the caller is an admin.
CREATE POLICY users_insert_self_or_admin ON public.users
  FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid()::text OR public.is_admin());

-- Update: own row, or any row when the caller is an admin (cross-user editing).
CREATE POLICY users_update_self_or_admin ON public.users
  FOR UPDATE TO authenticated
  USING (id = auth.uid()::text OR public.is_admin())
  WITH CHECK (id = auth.uid()::text OR public.is_admin());

-- Delete: admin only.
CREATE POLICY users_delete_admin ON public.users
  FOR DELETE TO authenticated
  USING (public.is_admin());

-- ------------------------------------------------------------
-- 6. RLS policies for reviews (admin/cashier can reply)
-- ------------------------------------------------------------
DROP POLICY IF EXISTS staff_update_reviews ON public.reviews;

CREATE POLICY staff_update_reviews ON public.reviews
  FOR UPDATE TO authenticated
  USING (public.is_staff())
  WITH CHECK (public.is_staff());

-- ------------------------------------------------------------
-- 7. RLS policies for products (admin/cashier can manage)
--    NOTE: a FOR ALL policy also gates SELECT, so only enable RLS on
--    `products` together with a separate public read policy — otherwise the
--    catalog becomes invisible to customers. RLS state of this table is left
--    untouched here; only the role lookup is corrected.
-- ------------------------------------------------------------
DROP POLICY IF EXISTS staff_manage_products ON public.products;

CREATE POLICY staff_manage_products ON public.products
  FOR ALL TO authenticated
  USING (public.is_staff())
  WITH CHECK (public.is_staff());

-- ------------------------------------------------------------
-- 8. Verification (expected: the four users_* policies above)
-- ------------------------------------------------------------
SELECT policyname, cmd, roles
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'users'
ORDER BY policyname;
