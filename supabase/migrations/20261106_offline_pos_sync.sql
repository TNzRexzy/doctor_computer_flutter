-- Idempotency records bridge local POS UUIDs to authoritative server rows.
CREATE TABLE IF NOT EXISTS public.pos_sync_shifts (
  cashier_id varchar(50) NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  local_shift_id uuid NOT NULL,
  remote_shift_id uuid NOT NULL REFERENCES public.cashier_shifts(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (cashier_id, local_shift_id),
  UNIQUE (remote_shift_id)
);

CREATE TABLE IF NOT EXISTS public.pos_sync_orders (
  cashier_id varchar(50) NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  local_order_id uuid NOT NULL,
  remote_order_id varchar(50) NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (cashier_id, local_order_id),
  UNIQUE (remote_order_id)
);

ALTER TABLE public.pos_sync_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pos_sync_orders ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pos_sync_shifts FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.pos_sync_orders FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.sync_open_cashier_shift(
  p_local_shift_id uuid,
  p_opening_cash numeric,
  p_notes text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid text := auth.uid()::text;
  v_remote_id uuid;
  v_shift public.cashier_shifts%ROWTYPE;
BEGIN
  IF v_uid IS NULL OR NOT public.is_staff() THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  IF p_local_shift_id IS NULL THEN
    RAISE EXCEPTION 'Local shift ID is required';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended(v_uid || ':open-cashier-shift', 0)
  );
  PERFORM pg_advisory_xact_lock(
    hashtextextended(v_uid || ':' || p_local_shift_id::text, 0)
  );
  SELECT remote_shift_id INTO v_remote_id
  FROM public.pos_sync_shifts
  WHERE cashier_id = v_uid AND local_shift_id = p_local_shift_id;
  IF v_remote_id IS NOT NULL THEN
    SELECT * INTO v_shift FROM public.cashier_shifts WHERE id = v_remote_id;
    RETURN to_jsonb(v_shift);
  END IF;

  v_shift := jsonb_populate_record(
    NULL::public.cashier_shifts,
    public.open_cashier_shift(p_opening_cash, p_notes)
  );
  INSERT INTO public.pos_sync_shifts (cashier_id, local_shift_id, remote_shift_id)
  VALUES (v_uid, p_local_shift_id, v_shift.id);
  RETURN to_jsonb(v_shift);
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_close_cashier_shift(
  p_local_shift_id uuid,
  p_closing_cash numeric,
  p_notes text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid text := auth.uid()::text;
  v_remote_id uuid;
  v_shift public.cashier_shifts%ROWTYPE;
BEGIN
  IF v_uid IS NULL OR NOT public.is_staff() THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  SELECT remote_shift_id INTO v_remote_id
  FROM public.pos_sync_shifts
  WHERE cashier_id = v_uid AND local_shift_id = p_local_shift_id;
  IF v_remote_id IS NULL THEN
    RAISE EXCEPTION 'Local shift has not been opened on the server';
  END IF;

  SELECT * INTO v_shift FROM public.cashier_shifts WHERE id = v_remote_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Synchronized shift not found';
  END IF;
  IF v_shift.status = 'open' THEN
    RETURN public.close_cashier_shift(
      v_remote_id, p_closing_cash, p_notes
    );
  END IF;
  RETURN to_jsonb(v_shift);
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_pos_order(
  p_local_order_id uuid,
  p_local_shift_id uuid,
  p_payment_method text,
  p_expected_total numeric,
  p_items jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid text := auth.uid()::text;
  v_remote_id varchar(50);
  v_remote_shift_id uuid;
  v_shift public.cashier_shifts%ROWTYPE;
  v_order jsonb;
BEGIN
  IF v_uid IS NULL OR NOT public.is_staff() THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  IF p_local_order_id IS NULL OR p_local_shift_id IS NULL THEN
    RAISE EXCEPTION 'Local order and shift IDs are required';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended(v_uid || ':' || p_local_order_id::text, 0)
  );
  SELECT remote_order_id INTO v_remote_id
  FROM public.pos_sync_orders
  WHERE cashier_id = v_uid AND local_order_id = p_local_order_id;
  IF v_remote_id IS NOT NULL THEN
    SELECT to_jsonb(o) || jsonb_build_object(
      'items', COALESCE(o.items_summary, '[]'::jsonb)
    ) INTO v_order
    FROM public.orders o
    WHERE o.id = v_remote_id;
    RETURN v_order;
  END IF;

  SELECT remote_shift_id INTO v_remote_shift_id
  FROM public.pos_sync_shifts
  WHERE cashier_id = v_uid AND local_shift_id = p_local_shift_id;
  IF v_remote_shift_id IS NULL THEN
    RAISE EXCEPTION 'Local shift has not been synchronized';
  END IF;
  SELECT * INTO v_shift
  FROM public.cashier_shifts
  WHERE id = v_remote_shift_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Synchronized cashier shift was not found';
  END IF;
  IF v_shift.cashier_id <> v_uid OR v_shift.status <> 'open' THEN
    RAISE EXCEPTION 'Synchronized cashier shift is not open';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM public.cashier_shifts
    WHERE cashier_id = v_uid
      AND status = 'open'
      AND id <> v_remote_shift_id
  ) THEN
    RAISE EXCEPTION 'Another open cashier shift exists';
  END IF;

  v_order := public.create_pos_order(
    v_uid, p_expected_total, p_payment_method, p_items
  );
  v_remote_id := v_order ->> 'id';
  IF v_remote_id IS NULL THEN
    RAISE EXCEPTION 'POS order creation returned no order ID';
  END IF;
  INSERT INTO public.pos_sync_orders (
    cashier_id, local_order_id, remote_order_id
  ) VALUES (v_uid, p_local_order_id, v_remote_id);
  RETURN v_order;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_open_cashier_shift(uuid, numeric, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.sync_close_cashier_shift(uuid, numeric, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.sync_pos_order(uuid, uuid, text, numeric, jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sync_open_cashier_shift(uuid, numeric, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.sync_close_cashier_shift(uuid, numeric, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.sync_pos_order(uuid, uuid, text, numeric, jsonb)
  TO authenticated;
