-- Run after add_admin_features.sql. This migration removes the permissive
-- orders/shifts policies and moves order creation and inventory changes to RPCs.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS role varchar(20) NOT NULL DEFAULT 'client',
  ADD COLUMN IF NOT EXISTS profile_image_url varchar(255),
  ADD COLUMN IF NOT EXISTS latitude double precision,
  ADD COLUMN IF NOT EXISTS longitude double precision;

ALTER TABLE public.users
  ALTER COLUMN role SET DEFAULT 'client';

DO $$
BEGIN
  IF to_regclass('public.roles') IS NOT NULL THEN
    INSERT INTO public.roles (code, name)
    VALUES ('client', 'Customer')
    ON CONFLICT (code) DO NOTHING;
  END IF;
END;
$$;

UPDATE public.users SET role = 'client' WHERE role = 'user';

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS cashier_id varchar(50),
  ADD COLUMN IF NOT EXISTS channel varchar(20) NOT NULL DEFAULT 'online',
  ADD COLUMN IF NOT EXISTS tracking_number varchar(100),
  ADD COLUMN IF NOT EXISTS courier varchar(100),
  ADD COLUMN IF NOT EXISTS serial_number varchar(100),
  ADD COLUMN IF NOT EXISTS warranty_months integer NOT NULL DEFAULT 24,
  ADD COLUMN IF NOT EXISTS rating numeric(3,2),
  ADD COLUMN IF NOT EXISTS review_comment text,
  ADD COLUMN IF NOT EXISTS rated_at timestamptz,
  ADD COLUMN IF NOT EXISTS review_media_urls jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS items_summary jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS points_awarded integer NOT NULL DEFAULT 0;

ALTER TABLE public.orders
  ALTER COLUMN tracking_number DROP DEFAULT,
  ALTER COLUMN courier DROP DEFAULT,
  ALTER COLUMN serial_number DROP DEFAULT;

ALTER TABLE public.order_items
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

CREATE TABLE IF NOT EXISTS public.cashier_shifts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cashier_id varchar(50) NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  opening_cash numeric(14,2) NOT NULL DEFAULT 0 CHECK (opening_cash >= 0),
  total_sales numeric(14,2) NOT NULL DEFAULT 0 CHECK (total_sales >= 0),
  total_orders integer NOT NULL DEFAULT 0 CHECK (total_orders >= 0),
  closing_cash numeric(14,2),
  variance numeric(14,2),
  status varchar(10) NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  notes text NOT NULL DEFAULT '',
  opened_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz
);

ALTER TABLE public.cashier_shifts
  ADD COLUMN IF NOT EXISTS cashier_id varchar(50),
  ADD COLUMN IF NOT EXISTS opening_cash numeric(14,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_sales numeric(14,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_orders integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS closing_cash numeric(14,2),
  ADD COLUMN IF NOT EXISTS variance numeric(14,2),
  ADD COLUMN IF NOT EXISTS status varchar(10) NOT NULL DEFAULT 'open',
  ADD COLUMN IF NOT EXISTS notes text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS opened_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS closed_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_cashier_shifts_cashier_opened
  ON public.cashier_shifts (cashier_id, opened_at DESC);

-- Profiles are created inside the Auth transaction. Role is never copied from
-- user metadata; only a trusted server-side provisioning path may grant staff.
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.users (id, full_name, email, phone, role)
  VALUES (
    NEW.id::text,
    COALESCE(NULLIF(NEW.raw_user_meta_data ->> 'full_name', ''), split_part(NEW.email, '@', 1)),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data ->> 'phone', ''),
    'client'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created_profile ON auth.users;
CREATE TRIGGER on_auth_user_created_profile
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

REVOKE ALL ON FUNCTION public.handle_new_auth_user() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT u.role FROM public.users u WHERE u.id = auth.uid()::text LIMIT 1;
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

GRANT EXECUTE ON FUNCTION public.current_user_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_staff() TO authenticated;

CREATE OR REPLACE FUNCTION public.create_order_internal(
  p_items jsonb,
  p_shipping_address text,
  p_payment_method text,
  p_shipping_method text,
  p_channel text,
  p_expected_total numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id text := auth.uid()::text;
  v_order_id varchar(50) := 'DC-' || replace(gen_random_uuid()::text, '-', '');
  v_item record;
  v_product public.products%ROWTYPE;
  v_lines jsonb := '[]'::jsonb;
  v_line jsonb;
  v_subtotal numeric(14,2) := 0;
  v_shipping numeric(14,2) := 0;
  v_total numeric(14,2);
  v_order public.orders%ROWTYPE;
  v_result jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF p_channel NOT IN ('online', 'pos') THEN
    RAISE EXCEPTION 'Invalid order channel';
  END IF;
  IF p_channel = 'pos' AND NOT public.is_staff() THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  IF p_channel = 'online' AND public.is_staff() THEN
    RAISE EXCEPTION 'Staff must create POS orders through the cashier flow' USING ERRCODE = '42501';
  END IF;
  IF jsonb_typeof(p_items) IS DISTINCT FROM 'array'
     OR jsonb_array_length(p_items) = 0
     OR jsonb_array_length(p_items) > 100 THEN
    RAISE EXCEPTION 'Order must contain between 1 and 100 items';
  END IF;
  IF p_payment_method IS NULL OR length(trim(p_payment_method)) = 0
     OR length(p_payment_method) > 50 THEN
    RAISE EXCEPTION 'Invalid payment method';
  END IF;
  IF (p_channel = 'online' AND p_payment_method NOT IN (
        'Transfer Bank BCA', 'Transfer Bank Mandiri', 'Transfer Bank BNI',
        'GoPay', 'OVO', 'Dana', 'ShopeePay', 'COD'
      ))
     OR (p_channel = 'pos' AND p_payment_method NOT IN ('Cash', 'QRIS', 'Debit BCA')) THEN
    RAISE EXCEPTION 'Unsupported payment method';
  END IF;

  IF p_channel = 'online' THEN
    IF p_shipping_address IS NULL OR length(trim(p_shipping_address)) < 5
       OR length(p_shipping_address) > 1000 THEN
      RAISE EXCEPTION 'Invalid shipping address';
    END IF;
    v_shipping := CASE p_shipping_method
      WHEN 'Reguler' THEN 15000
      WHEN 'Ekspres' THEN 30000
      WHEN 'Hari Ini' THEN 50000
      ELSE NULL
    END;
    IF v_shipping IS NULL THEN
      RAISE EXCEPTION 'Invalid shipping method';
    END IF;
  ELSE
    v_shipping := 0;
  END IF;

  FOR v_item IN
    SELECT value ->> 'product_id' AS product_id,
           sum((value ->> 'quantity')::integer)::integer AS quantity
    FROM jsonb_array_elements(p_items) AS item(value)
    GROUP BY value ->> 'product_id'
    ORDER BY value ->> 'product_id'
  LOOP
    IF v_item.product_id IS NULL OR v_item.quantity IS NULL
       OR v_item.quantity < 1 OR v_item.quantity > 1000 THEN
      RAISE EXCEPTION 'Invalid order item';
    END IF;

    SELECT p.* INTO v_product
    FROM public.products p
    WHERE p.id = v_item.product_id
    FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Product % is not available', v_item.product_id;
    END IF;
    IF v_product.stock < v_item.quantity THEN
      RAISE EXCEPTION 'Insufficient stock for product %', v_item.product_id;
    END IF;

    UPDATE public.products
    SET stock = stock - v_item.quantity
    WHERE id = v_item.product_id;
    v_subtotal := v_subtotal + (v_product.price * v_item.quantity);
    v_lines := v_lines || jsonb_build_array(jsonb_build_object(
      'product_id', v_product.id,
      'product_name', v_product.name,
      'product_price', v_product.price,
      'product_image', COALESCE(v_product.image_url[1], ''),
      'category_id', COALESCE(v_product.category_id, ''),
      'brand', v_product.brand,
      'unit_price', v_product.price,
      'quantity', v_item.quantity
    ));
  END LOOP;

  v_total := v_subtotal + v_shipping;
  IF p_expected_total IS NOT NULL AND p_expected_total <> v_total THEN
    RAISE EXCEPTION 'Cart prices changed. Refresh the cart and try again.';
  END IF;
  INSERT INTO public.orders (
    id, user_id, cashier_id, total_price, status, shipping_address,
    payment_method, channel, courier, serial_number, items_summary
  )
  VALUES (
    v_order_id,
    CASE WHEN p_channel = 'online' THEN v_user_id ELSE NULL END,
    CASE WHEN p_channel = 'pos' THEN v_user_id ELSE NULL END,
    v_total,
    CASE WHEN p_channel = 'pos' THEN 'delivered' ELSE 'processing' END,
    CASE WHEN p_channel = 'pos' THEN 'Ambil di Toko (POS Kasir)' ELSE trim(p_shipping_address) END,
    p_payment_method,
    p_channel,
    CASE WHEN p_channel = 'pos' THEN 'POS Kasir' ELSE p_shipping_method END,
    'SN-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)),
    v_lines
  )
  RETURNING * INTO v_order;

  FOR v_line IN SELECT value FROM jsonb_array_elements(v_lines)
  LOOP
    INSERT INTO public.order_items (order_id, product_id, quantity, unit_price)
    VALUES (
      v_order_id,
      v_line ->> 'product_id',
      (v_line ->> 'quantity')::integer,
      (v_line ->> 'unit_price')::numeric
    );
  END LOOP;

  IF p_channel = 'pos' THEN
    UPDATE public.cashier_shifts
    SET total_sales = total_sales + v_total,
        total_orders = total_orders + 1
    WHERE cashier_id = v_user_id AND status = 'open';
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Open a cashier shift before processing a sale';
    END IF;
  END IF;

  v_result := to_jsonb(v_order) || jsonb_build_object('items', v_lines);
  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_customer_order(
  p_items jsonb,
  p_shipping_address text,
  p_payment_method text,
  p_shipping_method text
)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.create_order_internal(
    p_items, p_shipping_address, p_payment_method, p_shipping_method, 'online'
  );
$$;

CREATE OR REPLACE FUNCTION public.create_pos_order(
  p_cashier_id text,
  p_total_price numeric,
  p_payment_method text,
  p_items jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_cashier_id IS DISTINCT FROM auth.uid()::text THEN
    RAISE EXCEPTION 'Cashier identity mismatch' USING ERRCODE = '42501';
  END IF;
  RETURN public.create_order_internal(
    p_items, 'Ambil di Toko (POS Kasir)', p_payment_method, 'POS', 'pos',
    p_total_price
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.open_cashier_shift(
  p_opening_cash numeric,
  p_notes text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_shift public.cashier_shifts%ROWTYPE;
  v_user_id text := auth.uid()::text;
BEGIN
  IF v_user_id IS NULL OR NOT public.is_staff() THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  IF p_opening_cash IS NULL OR p_opening_cash < 0 THEN
    RAISE EXCEPTION 'Opening cash must be non-negative';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.cashier_shifts
    WHERE cashier_id = v_user_id AND status = 'open'
  ) THEN
    RAISE EXCEPTION 'An open shift already exists for this cashier';
  END IF;
  INSERT INTO public.cashier_shifts (cashier_id, opening_cash, notes)
  VALUES (v_user_id, p_opening_cash, COALESCE(p_notes, ''))
  RETURNING * INTO v_shift;
  RETURN to_jsonb(v_shift);
END;
$$;

CREATE OR REPLACE FUNCTION public.close_cashier_shift(
  p_shift_id uuid,
  p_closing_cash numeric,
  p_notes text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_shift public.cashier_shifts%ROWTYPE;
  v_user_id text := auth.uid()::text;
BEGIN
  IF v_user_id IS NULL OR NOT public.is_staff() THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  IF p_closing_cash IS NULL OR p_closing_cash < 0 THEN
    RAISE EXCEPTION 'Closing cash must be non-negative';
  END IF;
  UPDATE public.cashier_shifts
  SET status = 'closed',
      closing_cash = p_closing_cash,
      variance = p_closing_cash - opening_cash - total_sales,
      closed_at = now(),
      notes = COALESCE(p_notes, '')
  WHERE id = p_shift_id
    AND status = 'open'
    AND (cashier_id = v_user_id OR public.is_admin())
  RETURNING * INTO v_shift;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Open shift was not found or cannot be closed' USING ERRCODE = '42501';
  END IF;
  RETURN to_jsonb(v_shift);
END;
$$;

CREATE OR REPLACE FUNCTION public.update_order_status(
  p_order_id varchar,
  p_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_order public.orders%ROWTYPE;
BEGIN
  IF NOT public.is_staff() THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  IF p_status NOT IN ('processing', 'shipped', 'delivered', 'cancelled') THEN
    RAISE EXCEPTION 'Invalid order status';
  END IF;
  UPDATE public.orders SET status = p_status WHERE id = p_order_id
  RETURNING * INTO v_order;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF v_order.status = 'delivered'
     AND v_order.user_id IS NOT NULL
     AND v_order.points_awarded = 0 THEN
    UPDATE public.users
    SET points = points + 500,
        membership_tier = CASE
          WHEN points + 500 >= 1200 THEN 'platinum'
          WHEN points + 500 >= 600 THEN 'gold'
          WHEN points + 500 >= 300 THEN 'silver'
          ELSE 'bronze'
        END
    WHERE id = v_order.user_id;
    UPDATE public.orders SET points_awarded = 500 WHERE id = p_order_id
    RETURNING * INTO v_order;
  END IF;
  RETURN to_jsonb(v_order);
END;
$$;

CREATE OR REPLACE FUNCTION public.rate_order(
  p_order_id varchar,
  p_rating numeric,
  p_comment text,
  p_media_urls jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_order public.orders%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
    RAISE EXCEPTION 'Rating must be between 1 and 5';
  END IF;
  IF p_comment IS NULL OR length(p_comment) > 3000
     OR jsonb_typeof(p_media_urls) IS DISTINCT FROM 'array'
     OR jsonb_array_length(p_media_urls) > 10 THEN
    RAISE EXCEPTION 'Invalid review data';
  END IF;

  UPDATE public.orders
  SET rating = p_rating,
      review_comment = p_comment,
      rated_at = now(),
      review_media_urls = p_media_urls
  WHERE id = p_order_id
    AND user_id = auth.uid()::text
    AND status = 'delivered'
    AND (rated_at IS NULL OR rated_at >= now() - interval '7 days')
  RETURNING * INTO v_order;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order cannot be rated by this user' USING ERRCODE = '42501';
  END IF;
  RETURN to_jsonb(v_order);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_update_user(
  p_user_id varchar,
  p_full_name text,
  p_points integer,
  p_role text,
  p_membership_tier text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user public.users%ROWTYPE;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admin authorization required' USING ERRCODE = '42501';
  END IF;
  IF p_full_name IS NULL OR length(trim(p_full_name)) NOT BETWEEN 1 AND 100
     OR p_points IS NULL OR p_points < 0
     OR p_role NOT IN ('client', 'cashier', 'admin')
     OR p_membership_tier NOT IN ('bronze', 'silver', 'gold', 'platinum') THEN
    RAISE EXCEPTION 'Invalid user update';
  END IF;

  UPDATE public.users
  SET full_name = trim(p_full_name),
      points = p_points,
      role = p_role,
      membership_tier = p_membership_tier
  WHERE id = p_user_id
  RETURNING * INTO v_user;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found';
  END IF;
  RETURN to_jsonb(v_user);
END;
$$;

REVOKE ALL ON FUNCTION public.create_order_internal(jsonb, text, text, text, text, numeric) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.create_customer_order(jsonb, text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.create_pos_order(text, numeric, text, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.open_cashier_shift(numeric, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.close_cashier_shift(uuid, numeric, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.update_order_status(varchar, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rate_order(varchar, numeric, text, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_update_user(varchar, text, integer, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_customer_order(jsonb, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_pos_order(text, numeric, text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.open_cashier_shift(numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_cashier_shift(uuid, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_order_status(varchar, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rate_order(varchar, numeric, text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_user(varchar, text, integer, text, text) TO authenticated;

DO $$
DECLARE
  v_policy record;
BEGIN
  FOR v_policy IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('orders', 'order_items', 'cashier_shifts', 'products')
  LOOP
    EXECUTE format('DROP POLICY %I ON %I.%I',
      v_policy.policyname, v_policy.schemaname, v_policy.tablename);
  END LOOP;
END;
$$;

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cashier_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS users_insert_self_or_admin ON public.users;
CREATE POLICY users_insert_self_or_admin ON public.users
  FOR INSERT TO authenticated
  WITH CHECK (
    (id = auth.uid()::text AND role = 'client'
      AND points = 0 AND membership_tier = 'bronze')
    OR public.is_admin()
  );

CREATE POLICY orders_select_owner_or_staff ON public.orders
  FOR SELECT TO authenticated
  USING (user_id = auth.uid()::text OR public.is_staff());

CREATE POLICY orders_update_staff_only ON public.orders
  FOR UPDATE TO authenticated
  USING (public.is_staff())
  WITH CHECK (public.is_staff());

CREATE POLICY order_items_select_owner_or_staff ON public.order_items
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.orders o
      WHERE o.id = order_items.order_id
        AND (o.user_id = auth.uid()::text OR public.is_staff())
    )
  );

CREATE POLICY cashier_shifts_select_owner_or_admin ON public.cashier_shifts
  FOR SELECT TO authenticated
  USING (cashier_id = auth.uid()::text OR public.is_admin());

CREATE POLICY products_select_public ON public.products
  FOR SELECT TO anon, authenticated
  USING (true);

CREATE POLICY products_manage_staff ON public.products
  FOR ALL TO authenticated
  USING (public.is_staff())
  WITH CHECK (public.is_staff());

REVOKE INSERT, UPDATE, DELETE ON public.orders FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.order_items FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.cashier_shifts FROM anon, authenticated;
REVOKE UPDATE ON public.users FROM PUBLIC, anon, authenticated;
GRANT UPDATE (full_name, phone, address, city, avatar_url, profile_image_url,
  latitude, longitude, updated_at) ON public.users TO authenticated;

DO $$
DECLARE
  v_policy record;
BEGIN
  IF to_regclass('public.blockchain_blocks') IS NOT NULL THEN
    FOR v_policy IN
      SELECT policyname
      FROM pg_policies
      WHERE schemaname = 'public' AND tablename = 'blockchain_blocks'
    LOOP
      EXECUTE format('DROP POLICY %I ON public.blockchain_blocks', v_policy.policyname);
    END LOOP;
    ALTER TABLE public.blockchain_blocks ENABLE ROW LEVEL SECURITY;
    EXECUTE 'CREATE POLICY blockchain_blocks_select_owner_or_staff ON public.blockchain_blocks
      FOR SELECT TO authenticated
      USING (user_id = auth.uid()::text OR public.is_staff())';
    REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.blockchain_blocks FROM PUBLIC, anon, authenticated;
  END IF;
END;
$$;

-- Database-only verification: execute as authenticated users with customer,
-- cashier, and admin JWT claims to confirm the intended row visibility.
