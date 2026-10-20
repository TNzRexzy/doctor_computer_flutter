-- ============================================================
-- MIGRATION: Admin features - role column, review replies
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. Add 'role' column to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS role varchar(20) NOT NULL DEFAULT 'user';

-- 2. Add reply columns to reviews table
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS reply text;
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS reply_role varchar(20);
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS reply_date timestamptz;
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS user_name varchar(100);

-- 3. Update existing admin/cashier accounts with correct roles
UPDATE users SET role = 'admin' WHERE email = 'admin@doctorcomputer.id';
UPDATE users SET role = 'cashier' WHERE email = 'cashier@doctorcomputer.id';

-- 4. RLS policies for admin user management
-- Allow admin to update any user's data
CREATE POLICY IF NOT EXISTS admin_update_users ON users
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM users AS u
      WHERE u.id = auth.uid()
      AND u.role = 'admin'
    )
  );

-- Allow users to update their own data
CREATE POLICY IF NOT EXISTS user_update_own ON users
  FOR UPDATE
  USING (id = auth.uid()::varchar);

-- Allow admin to read all users
CREATE POLICY IF NOT EXISTS admin_read_all_users ON users
  FOR SELECT
  USING (
    id = auth.uid()::varchar
    OR EXISTS (
      SELECT 1 FROM users AS u
      WHERE u.id = auth.uid()::varchar
      AND u.role IN ('admin', 'cashier')
    )
  );

-- 5. RLS policies for reviews (admin/cashier can reply)
CREATE POLICY IF NOT EXISTS staff_update_reviews ON reviews
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM users AS u
      WHERE u.id = auth.uid()::varchar
      AND u.role IN ('admin', 'cashier')
    )
  );

-- 6. RLS policies for products (admin/cashier can manage)
CREATE POLICY IF NOT EXISTS staff_manage_products ON products
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users AS u
      WHERE u.id = auth.uid()::varchar
      AND u.role IN ('admin', 'cashier')
    )
  );
