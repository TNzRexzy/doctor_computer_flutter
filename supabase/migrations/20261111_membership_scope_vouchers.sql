-- Personalized membership vouchers and trusted checkout support for PC builds.
-- Apply after 20261104_vouchers.sql, 20261105_available_vouchers.sql,
-- 20261106_pc_parts_staff_insert.sql, and the order schema/RPC migrations.

ALTER TABLE public.pc_parts
  ADD COLUMN IF NOT EXISTS product_id varchar(50)
    REFERENCES public.products(id) ON DELETE SET NULL;

WITH product_matches AS (
  SELECT DISTINCT ON (lower(trim(p.name)))
    lower(trim(p.name)) AS name_key,
    p.id AS product_id
  FROM public.products p
  WHERE coalesce(trim(p.name), '') <> ''
  ORDER BY lower(trim(p.name)), p.created_at DESC, p.id
)
UPDATE public.pc_parts pp
SET product_id = matches.product_id
FROM product_matches matches
WHERE pp.product_id IS NULL
  AND lower(trim(pp.name)) = matches.name_key;

ALTER TABLE public.vouchers
  ADD COLUMN IF NOT EXISTS discount_scope text NOT NULL DEFAULT 'all',
  ADD COLUMN IF NOT EXISTS assigned_user_id varchar(50)
    REFERENCES public.users(id)
    ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS reward_type text,
  ADD COLUMN IF NOT EXISTS reward_period date;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.vouchers'::regclass
      AND conname = 'vouchers_discount_scope_check'
  ) THEN
    ALTER TABLE public.vouchers
      ADD CONSTRAINT vouchers_discount_scope_check
      CHECK (discount_scope IN ('all', 'product', 'build_service', 'shipping'));
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.vouchers'::regclass
      AND conname = 'vouchers_reward_type_check'
  ) THEN
    ALTER TABLE public.vouchers
      ADD CONSTRAINT vouchers_reward_type_check
      CHECK (
        reward_type IS NULL
        OR reward_type IN ('weekly_build', 'weekly_shipping', 'monthly_product')
      );
  END IF;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS vouchers_member_reward_period_idx
  ON public.vouchers (assigned_user_id, reward_type, reward_period)
  WHERE assigned_user_id IS NOT NULL
    AND reward_type IS NOT NULL
    AND reward_period IS NOT NULL;

CREATE OR REPLACE FUNCTION public.validate_voucher(
  p_code text,
  p_subtotal numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id text := auth.uid()::text;
  v_voucher public.vouchers%ROWTYPE;
  v_user_uses integer;
  v_discount numeric(14,2);
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF public.is_staff() THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Voucher hanya dapat digunakan oleh pembeli.'
    );
  END IF;
  IF p_code IS NULL OR length(trim(p_code)) = 0
     OR p_subtotal IS NULL OR p_subtotal < 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Kode voucher atau subtotal tidak valid.'
    );
  END IF;

  SELECT * INTO v_voucher
  FROM public.vouchers
  WHERE code = upper(trim(p_code));

  IF NOT FOUND OR NOT v_voucher.is_active THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Voucher tidak ditemukan atau sudah dinonaktifkan.'
    );
  END IF;
  IF v_voucher.assigned_user_id IS NOT NULL
     AND v_voucher.assigned_user_id <> v_user_id THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Voucher ini bukan milik akun Anda.'
    );
  END IF;
  IF now() < v_voucher.starts_at OR now() >= v_voucher.expires_at THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Voucher belum berlaku atau sudah kedaluwarsa.'
    );
  END IF;
  IF v_voucher.usage_limit IS NOT NULL
     AND v_voucher.used_count >= v_voucher.usage_limit THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Kuota voucher sudah habis.'
    );
  END IF;
  IF p_subtotal < v_voucher.min_purchase THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', format(
        'Minimal belanja untuk voucher ini %s.',
        to_char(v_voucher.min_purchase, 'FM999G999G999G990')
      )
    );
  END IF;

  SELECT count(*) INTO v_user_uses
  FROM public.voucher_redemptions
  WHERE voucher_id = v_voucher.id AND user_id = v_user_id;
  IF v_user_uses >= v_voucher.per_user_limit THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Batas pemakaian voucher untuk akun Anda sudah tercapai.'
    );
  END IF;

  IF v_voucher.discount_type = 'percent' THEN
    v_discount := round(p_subtotal * v_voucher.discount_value / 100, 2);
    IF v_voucher.max_discount IS NOT NULL THEN
      v_discount := least(v_discount, v_voucher.max_discount);
    END IF;
  ELSE
    v_discount := v_voucher.discount_value;
  END IF;
  v_discount := least(v_discount, p_subtotal);

  RETURN jsonb_build_object(
    'success', true,
    'code', v_voucher.code,
    'title', v_voucher.title,
    'discount_scope', v_voucher.discount_scope,
    'discount_amount', v_discount,
    'message', 'Voucher berhasil digunakan.'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.list_available_vouchers(
  p_subtotal numeric
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id text := auth.uid()::text;
  v_vouchers jsonb;
BEGIN
  IF v_user_id IS NULL OR public.is_staff()
     OR p_subtotal IS NULL OR p_subtotal < 0 THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', eligible.id,
        'code', eligible.code,
        'title', eligible.title,
        'discount_type', eligible.discount_type,
        'discount_value', eligible.discount_value,
        'discount_scope', eligible.discount_scope,
        'max_discount', eligible.max_discount,
        'min_purchase', eligible.min_purchase,
        'usage_limit', eligible.usage_limit,
        'used_count', eligible.used_count,
        'per_user_limit', eligible.per_user_limit,
        'starts_at', eligible.starts_at,
        'expires_at', eligible.expires_at,
        'discount_amount', CASE
          WHEN eligible.discount_type = 'percent' THEN least(
            p_subtotal,
            CASE
              WHEN eligible.max_discount IS NULL THEN
                round(p_subtotal * eligible.discount_value / 100, 2)
              ELSE least(
                round(p_subtotal * eligible.discount_value / 100, 2),
                eligible.max_discount
              )
            END
          )
          ELSE least(p_subtotal, eligible.discount_value)
        END
      )
      ORDER BY eligible.expires_at, eligible.code
    ),
    '[]'::jsonb
  )
  INTO v_vouchers
  FROM public.vouchers AS eligible
  WHERE eligible.is_active
    AND now() >= eligible.starts_at
    AND now() < eligible.expires_at
    AND (eligible.assigned_user_id IS NULL
         OR eligible.assigned_user_id = v_user_id)
    AND (
      eligible.usage_limit IS NULL
      OR eligible.used_count < eligible.usage_limit
    )
    AND (
      SELECT count(*)
      FROM public.voucher_redemptions AS redemption
      WHERE redemption.voucher_id = eligible.id
        AND redemption.user_id = v_user_id
    ) < eligible.per_user_limit;

  RETURN v_vouchers;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_customer_order_with_membership(
  p_items jsonb,
  p_shipping_address text,
  p_payment_method text,
  p_shipping_method text,
  p_voucher_code text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id text := auth.uid()::text;
  v_product_items jsonb;
  v_service_count integer;
  v_service_id text;
  v_service_quantity integer;
  v_service_price numeric(14,2) := 0;
  v_service_name text;
  v_shipping numeric(14,2);
  v_product_subtotal numeric(14,2);
  v_eligible_subtotal numeric(14,2);
  v_discount numeric(14,2) := 0;
  v_order_data jsonb;
  v_order_id varchar(50);
  v_order public.orders%ROWTYPE;
  v_voucher public.vouchers%ROWTYPE;
  v_user_uses integer;
  v_items jsonb;
  v_service_line jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF public.is_staff() THEN
    RAISE EXCEPTION 'Staff must create POS orders through the cashier flow'
      USING ERRCODE = '42501';
  END IF;
  IF jsonb_typeof(p_items) IS DISTINCT FROM 'array'
     OR jsonb_array_length(p_items) = 0
     OR jsonb_array_length(p_items) > 100 THEN
    RAISE EXCEPTION 'Order must contain between 1 and 100 items';
  END IF;

  SELECT count(*) INTO v_service_count
  FROM jsonb_array_elements(p_items) AS item(value)
  WHERE item.value ->> 'product_id' IN (
    'build-service-standard', 'build-service-premium'
  );
  IF v_service_count > 1 THEN
    RAISE EXCEPTION 'An order can contain only one PC assembly service';
  END IF;

  SELECT item.value ->> 'product_id',
         (item.value ->> 'quantity')::integer
    INTO v_service_id, v_service_quantity
  FROM jsonb_array_elements(p_items) AS item(value)
  WHERE item.value ->> 'product_id' IN (
    'build-service-standard', 'build-service-premium'
  );

  IF v_service_count = 1 THEN
    IF v_service_quantity IS DISTINCT FROM 1 THEN
      RAISE EXCEPTION 'PC assembly service quantity must be one';
    END IF;
    IF v_service_id = 'build-service-standard' THEN
      v_service_price := 250000;
      v_service_name := 'Jasa Rakit PC Standard';
    ELSE
      v_service_price := 500000;
      v_service_name := 'Jasa Rakit PC Premium';
    END IF;
  END IF;

  SELECT jsonb_agg(item.value)
    INTO v_product_items
  FROM jsonb_array_elements(p_items) AS item(value)
  WHERE item.value ->> 'product_id' NOT IN (
    'build-service-standard', 'build-service-premium'
  );
  IF v_product_items IS NULL OR jsonb_array_length(v_product_items) = 0 THEN
    RAISE EXCEPTION 'Order must contain at least one catalog product';
  END IF;

  v_order_data := public.create_order_internal(
    v_product_items, p_shipping_address, p_payment_method,
    p_shipping_method, 'online'
  );
  v_order_id := v_order_data ->> 'id';
  IF v_order_id IS NULL THEN
    RAISE EXCEPTION 'Order could not be created';
  END IF;

  SELECT COALESCE(sum(quantity * unit_price), 0)
    INTO v_product_subtotal
  FROM public.order_items
  WHERE order_id = v_order_id
    AND product_id IS NOT NULL;

  v_shipping := CASE p_shipping_method
    WHEN 'Reguler' THEN 15000
    WHEN 'Ekspres' THEN 30000
    WHEN 'Hari Ini' THEN 50000
    ELSE NULL
  END;

  v_items := COALESCE(v_order_data -> 'items', '[]'::jsonb);
  IF v_service_count = 1 THEN
    v_service_line := jsonb_build_object(
      'product_id', v_service_id,
      'product_name', v_service_name,
      'product_price', v_service_price,
      'product_image', '',
      'category_id', 'service',
      'brand', 'Doctor Computer',
      'unit_price', v_service_price,
      'quantity', 1
    );
    v_items := v_items || jsonb_build_array(v_service_line);
    INSERT INTO public.order_items (order_id, product_id, quantity, unit_price)
    VALUES (v_order_id, NULL, 1, v_service_price);

    UPDATE public.orders
    SET total_price = total_price + v_service_price,
        items_summary = v_items
    WHERE id = v_order_id;
  END IF;

  IF p_voucher_code IS NOT NULL AND length(trim(p_voucher_code)) > 0 THEN
    SELECT * INTO v_voucher
    FROM public.vouchers
    WHERE code = upper(trim(p_voucher_code))
    FOR UPDATE;

    IF NOT FOUND OR NOT v_voucher.is_active THEN
      RAISE EXCEPTION 'Voucher tidak ditemukan atau sudah dinonaktifkan.';
    END IF;
    IF v_voucher.assigned_user_id IS NOT NULL
       AND v_voucher.assigned_user_id <> v_user_id THEN
      RAISE EXCEPTION 'Voucher ini bukan milik akun Anda.';
    END IF;
    IF now() < v_voucher.starts_at OR now() >= v_voucher.expires_at THEN
      RAISE EXCEPTION 'Voucher belum berlaku atau sudah kedaluwarsa.';
    END IF;
    IF v_voucher.usage_limit IS NOT NULL
       AND v_voucher.used_count >= v_voucher.usage_limit THEN
      RAISE EXCEPTION 'Kuota voucher sudah habis.';
    END IF;

    v_eligible_subtotal := CASE v_voucher.discount_scope
      WHEN 'product' THEN v_product_subtotal
      WHEN 'build_service' THEN v_service_price
      WHEN 'shipping' THEN v_shipping
      WHEN 'all' THEN v_product_subtotal + v_service_price
      ELSE 0
    END;
    IF v_eligible_subtotal < v_voucher.min_purchase
       OR v_eligible_subtotal <= 0 THEN
      RAISE EXCEPTION 'Subtotal belum memenuhi minimal belanja voucher.';
    END IF;

    SELECT count(*) INTO v_user_uses
    FROM public.voucher_redemptions
    WHERE voucher_id = v_voucher.id AND user_id = v_user_id;
    IF v_user_uses >= v_voucher.per_user_limit THEN
      RAISE EXCEPTION 'Batas pemakaian voucher untuk akun Anda sudah tercapai.';
    END IF;

    IF v_voucher.discount_type = 'percent' THEN
      v_discount := round(
        v_eligible_subtotal * v_voucher.discount_value / 100, 2
      );
      IF v_voucher.max_discount IS NOT NULL THEN
        v_discount := least(v_discount, v_voucher.max_discount);
      END IF;
    ELSE
      v_discount := v_voucher.discount_value;
    END IF;
    v_discount := least(v_discount, v_eligible_subtotal);

    UPDATE public.vouchers
    SET used_count = used_count + 1,
        updated_at = now()
    WHERE id = v_voucher.id;

    UPDATE public.orders
    SET total_price = total_price - v_discount,
        voucher_code = v_voucher.code,
        discount_amount = v_discount
    WHERE id = v_order_id;

    INSERT INTO public.voucher_redemptions (
      voucher_id, user_id, order_id, discount_amount
    )
    VALUES (v_voucher.id, v_user_id, v_order_id, v_discount);
  END IF;

  SELECT * INTO v_order
  FROM public.orders
  WHERE id = v_order_id;

  RETURN to_jsonb(v_order) || jsonb_build_object('items', v_items);
END;
$$;

CREATE OR REPLACE FUNCTION public.issue_membership_vouchers(
  p_frequency text
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user record;
  v_period date;
  v_period_key text;
  v_expires_at timestamptz;
  v_rate numeric(5,2);
  v_issued integer := 0;
  v_row_count integer;
  v_code text;
  v_scope text;
  v_reward_type text;
  v_title text;
BEGIN
  IF p_frequency NOT IN ('weekly', 'monthly') THEN
    RAISE EXCEPTION 'Frequency must be weekly or monthly';
  END IF;

  IF p_frequency = 'weekly' THEN
    v_period := date_trunc('week', now())::date;
    v_period_key := to_char(v_period, 'IYYYIW');
    v_expires_at := (v_period + 7)::timestamptz;
  ELSE
    v_period := date_trunc('month', now())::date;
    v_period_key := to_char(v_period, 'YYYYMM');
    v_expires_at := (v_period + interval '1 month')::timestamptz;
  END IF;

  FOR v_user IN
    SELECT id, points
    FROM public.users
    WHERE role = 'client'
  LOOP
    v_rate := CASE
      WHEN v_user.points >= 1200 THEN 20
      WHEN v_user.points >= 600 THEN 15
      WHEN v_user.points >= 300 THEN 10
      ELSE 5
    END;

    IF p_frequency = 'weekly' THEN
      FOREACH v_scope IN ARRAY ARRAY['build_service', 'shipping']
      LOOP
        IF v_scope = 'build_service' THEN
          v_reward_type := 'weekly_build';
          v_code := upper(
            'BA' || substr(md5(v_user.id::text), 1, 16) || v_period_key
          );
          v_title := 'Voucher Jasa Rakit PC Mingguan';
        ELSE
          v_reward_type := 'weekly_shipping';
          v_code := upper(
            'BS' || substr(md5(v_user.id::text), 1, 16) || v_period_key
          );
          v_title := 'Voucher Ongkir Mingguan';
        END IF;

        INSERT INTO public.vouchers (
          code, title, discount_type, discount_value, min_purchase,
          per_user_limit, starts_at, expires_at, is_active, discount_scope,
          assigned_user_id, reward_type, reward_period
        )
        VALUES (
          v_code, v_title, 'percent', v_rate, 0,
          1, v_period::timestamptz, v_expires_at, true, v_scope,
          v_user.id, v_reward_type, v_period
        )
        ON CONFLICT DO NOTHING;
        GET DIAGNOSTICS v_row_count = ROW_COUNT;
        v_issued := v_issued + v_row_count;
      END LOOP;
    ELSE
      v_code := upper(
        'PM' || substr(md5(v_user.id::text), 1, 16) || v_period_key
      );
      INSERT INTO public.vouchers (
        code, title, discount_type, discount_value, min_purchase,
        per_user_limit, starts_at, expires_at, is_active, discount_scope,
        assigned_user_id, reward_type, reward_period
      )
      VALUES (
        v_code, 'Voucher Produk Bulanan', 'percent', v_rate, 0,
        1, v_period::timestamptz, v_expires_at, true, 'product',
        v_user.id, 'monthly_product', v_period
      )
      ON CONFLICT DO NOTHING;
      GET DIAGNOSTICS v_row_count = ROW_COUNT;
      v_issued := v_issued + v_row_count;
    END IF;
  END LOOP;

  RETURN v_issued;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_customer_order_with_voucher(
  p_items jsonb,
  p_shipping_address text,
  p_payment_method text,
  p_shipping_method text,
  p_voucher_code text
)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.create_customer_order_with_membership(
    p_items, p_shipping_address, p_payment_method, p_shipping_method,
    p_voucher_code
  );
$$;

REVOKE ALL ON FUNCTION public.validate_voucher(text, numeric)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.validate_voucher(text, numeric)
  TO authenticated;

REVOKE ALL ON FUNCTION public.list_available_vouchers(numeric)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_available_vouchers(numeric)
  TO authenticated;

REVOKE ALL ON FUNCTION public.create_customer_order_with_membership(
  jsonb, text, text, text, text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_customer_order_with_membership(
  jsonb, text, text, text, text
) TO authenticated;

REVOKE ALL ON FUNCTION public.create_customer_order_with_voucher(
  jsonb, text, text, text, text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_customer_order_with_voucher(
  jsonb, text, text, text, text
) TO authenticated;

REVOKE ALL ON FUNCTION public.issue_membership_vouchers(text)
  FROM PUBLIC, anon, authenticated;

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;

DO $$
BEGIN
  PERFORM cron.unschedule(jobid)
  FROM cron.job
  WHERE jobname IN (
    'issue-membership-vouchers-weekly',
    'issue-membership-vouchers-monthly'
  );

  PERFORM cron.schedule(
    'issue-membership-vouchers-weekly',
    '5 0 * * 1',
    'SELECT public.issue_membership_vouchers(''weekly'');'
  );
  PERFORM cron.schedule(
    'issue-membership-vouchers-monthly',
    '5 0 1 * *',
    'SELECT public.issue_membership_vouchers(''monthly'');'
  );
END;
$$;

-- Populate the current periods as soon as the migration is applied rather
-- than leaving the first account without vouchers until the next cron run.
SELECT public.issue_membership_vouchers('weekly');
SELECT public.issue_membership_vouchers('monthly');
