-- ============================================================
-- FIX RLS POLICIES FOR cashier_shifts & orders
-- Memperbaiki error: "new row violates row-level security policy for table cashier_shifts" (code 42501)
-- ============================================================

-- 1. Pastikan tabel memiliki RLS aktif
ALTER TABLE public.cashier_shifts ENABLE ROW LEVEL SECURITY;

-- 2. Hapus policy lama yang hanya membolehkan SELECT
DROP POLICY IF EXISTS "shifts_select" ON public.cashier_shifts;
DROP POLICY IF EXISTS "shifts_insert" ON public.cashier_shifts;
DROP POLICY IF EXISTS "shifts_update" ON public.cashier_shifts;
DROP POLICY IF EXISTS "shifts_all" ON public.cashier_shifts;

-- 3. Buat Policy lengkap (SELECT, INSERT, UPDATE) untuk Kasir dan Admin
CREATE POLICY "shifts_select" ON public.cashier_shifts
FOR SELECT
USING (true);

CREATE POLICY "shifts_insert" ON public.cashier_shifts
FOR INSERT
WITH CHECK (true);

CREATE POLICY "shifts_update" ON public.cashier_shifts
FOR UPDATE
USING (true);

-- 4. Pastikan juga pesanan POS dapat di-insert/update oleh Kasir
DROP POLICY IF EXISTS "orders_pos_insert" ON public.orders;
CREATE POLICY "orders_pos_insert" ON public.orders
FOR INSERT
WITH CHECK (true);

DROP POLICY IF EXISTS "order_items_pos_insert" ON public.order_items;
CREATE POLICY "order_items_pos_insert" ON public.order_items
FOR INSERT
WITH CHECK (true);
