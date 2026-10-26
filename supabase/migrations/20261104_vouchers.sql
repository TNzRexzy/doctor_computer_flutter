CREATE TABLE IF NOT EXISTS public.vouchers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(40) NOT NULL UNIQUE
    CHECK (code = upper(trim(code)) AND code ~ '^[A-Z0-9_-]+$'),
  title varchar(120) NOT NULL,
  discount_type varchar(10) NOT NULL
    CHECK (discount_type IN ('percent', 'fixed')),
  discount_value numeric(14,2) NOT NULL CHECK (discount_value > 0),
  max_discount numeric(14,2)
    CHECK (max_discount IS NULL OR max_discount > 0),
  min_purchase numeric(14,2) NOT NULL DEFAULT 0 CHECK (min_purchase >= 0),
  usage_limit integer CHECK (usage_limit IS NULL OR usage_limit > 0),
  used_count integer NOT NULL DEFAULT 0 CHECK (used_count >= 0),
  per_user_limit integer NOT NULL DEFAULT 1 CHECK (per_user_limit > 0),
  starts_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT vouchers_expiry_after_start CHECK (expires_at > starts_at),
  CONSTRAINT vouchers_percent_max CHECK (
    discount_type <> 'percent' OR discount_value <= 100
  )
);

CREATE TABLE IF NOT EXISTS public.voucher_redemptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  voucher_id uuid NOT NULL REFERENCES public.vouchers(id),
  user_id text NOT NULL,
  order_id varchar(50) NOT NULL UNIQUE REFERENCES public.orders(id),
  discount_amount numeric(14,2) NOT NULL CHECK (discount_amount > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (voucher_id, user_id, order_id)
);

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS voucher_code varchar(40),
  ADD COLUMN IF NOT EXISTS discount_amount numeric(14,2) NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS voucher_redemptions_user_voucher_idx
  ON public.voucher_redemptions (voucher_id, user_id);

ALTER TABLE public.vouchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.voucher_redemptions ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON public.vouchers TO authenticated;

DROP POLICY IF EXISTS vouchers_admin_manage ON public.vouchers;
CREATE POLICY vouchers_admin_manage ON public.vouchers
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

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
    'discount_amount', v_discount,
    'message', 'Voucher berhasil digunakan.'
  );
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
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id text := auth.uid()::text;
  v_order_data jsonb;
  v_order_id varchar(50);
  v_order public.orders%ROWTYPE;
  v_voucher public.vouchers%ROWTYPE;
  v_subtotal numeric(14,2);
  v_discount numeric(14,2);
  v_user_uses integer;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF p_voucher_code IS NULL OR length(trim(p_voucher_code)) = 0 THEN
    RETURN public.create_order_internal(
      p_items, p_shipping_address, p_payment_method, p_shipping_method, 'online'
    );
  END IF;

  v_order_data := public.create_order_internal(
    p_items, p_shipping_address, p_payment_method, p_shipping_method, 'online'
  );
  v_order_id := v_order_data ->> 'id';
  IF v_order_id IS NULL THEN
    RAISE EXCEPTION 'Order could not be created';
  END IF;

  SELECT * INTO v_voucher
  FROM public.vouchers
  WHERE code = upper(trim(p_voucher_code))
  FOR UPDATE;

  IF NOT FOUND OR NOT v_voucher.is_active THEN
    RAISE EXCEPTION 'Voucher tidak ditemukan atau sudah dinonaktifkan.';
  END IF;
  IF now() < v_voucher.starts_at OR now() >= v_voucher.expires_at THEN
    RAISE EXCEPTION 'Voucher belum berlaku atau sudah kedaluwarsa.';
  END IF;
  IF v_voucher.usage_limit IS NOT NULL
     AND v_voucher.used_count >= v_voucher.usage_limit THEN
    RAISE EXCEPTION 'Kuota voucher sudah habis.';
  END IF;

  SELECT COALESCE(sum(quantity * unit_price), 0)
    INTO v_subtotal
  FROM public.order_items
  WHERE order_id = v_order_id;
  IF v_subtotal < v_voucher.min_purchase THEN
    RAISE EXCEPTION 'Subtotal belum memenuhi minimal belanja voucher.';
  END IF;

  SELECT count(*) INTO v_user_uses
  FROM public.voucher_redemptions
  WHERE voucher_id = v_voucher.id AND user_id = v_user_id;
  IF v_user_uses >= v_voucher.per_user_limit THEN
    RAISE EXCEPTION 'Batas pemakaian voucher untuk akun Anda sudah tercapai.';
  END IF;

  IF v_voucher.discount_type = 'percent' THEN
    v_discount := round(v_subtotal * v_voucher.discount_value / 100, 2);
    IF v_voucher.max_discount IS NOT NULL THEN
      v_discount := least(v_discount, v_voucher.max_discount);
    END IF;
  ELSE
    v_discount := v_voucher.discount_value;
  END IF;
  v_discount := least(v_discount, v_subtotal);

  UPDATE public.vouchers
  SET used_count = used_count + 1,
      updated_at = now()
  WHERE id = v_voucher.id;

  INSERT INTO public.voucher_redemptions (
    voucher_id, user_id, order_id, discount_amount
  )
  VALUES (v_voucher.id, v_user_id, v_order_id, v_discount);

  UPDATE public.orders
  SET total_price = total_price - v_discount,
      voucher_code = v_voucher.code,
      discount_amount = v_discount
  WHERE id = v_order_id
  RETURNING * INTO v_order;

  RETURN to_jsonb(v_order) || jsonb_build_object(
    'items', v_order_data -> 'items'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.validate_voucher(text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.validate_voucher(text, numeric) TO authenticated;

REVOKE ALL ON FUNCTION public.create_customer_order_with_voucher(
  jsonb, text, text, text, text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_customer_order_with_voucher(
  jsonb, text, text, text, text
) TO authenticated;
