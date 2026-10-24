-- Superseded by 20261024_harden_client_access.sql. Mutations now go through
-- authenticated server-side RPC functions; there are no permissive write rules.
ALTER TABLE public.cashier_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "shifts_select" ON public.cashier_shifts;
DROP POLICY IF EXISTS "shifts_insert" ON public.cashier_shifts;
DROP POLICY IF EXISTS "shifts_update" ON public.cashier_shifts;
DROP POLICY IF EXISTS "shifts_all" ON public.cashier_shifts;
DROP POLICY IF EXISTS "orders_pos_insert" ON public.orders;
DROP POLICY IF EXISTS "order_items_pos_insert" ON public.order_items;

DROP POLICY IF EXISTS cashier_shifts_select_owner_or_admin ON public.cashier_shifts;
CREATE POLICY cashier_shifts_select_owner_or_admin ON public.cashier_shifts
  FOR SELECT TO authenticated
  USING (cashier_id = auth.uid()::text OR public.is_admin());
