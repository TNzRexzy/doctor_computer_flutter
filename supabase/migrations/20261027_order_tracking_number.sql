-- Staff (admin + cashier) can input / update the courier and tracking number (resi)
-- of an order. Direct UPDATE on public.orders is revoked from authenticated users
-- (see 20261024_harden_client_access.sql), so this goes through a SECURITY DEFINER RPC.

CREATE OR REPLACE FUNCTION public.update_order_tracking(
  p_order_id varchar,
  p_courier text,
  p_tracking_number text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_order public.orders%ROWTYPE;
  v_courier text := NULLIF(btrim(COALESCE(p_courier, '')), '');
  v_tracking text := NULLIF(btrim(COALESCE(p_tracking_number, '')), '');
BEGIN
  IF NOT public.is_staff() THEN
    RAISE EXCEPTION 'Staff authorization required' USING ERRCODE = '42501';
  END IF;
  IF v_tracking IS NULL THEN
    RAISE EXCEPTION 'Tracking number is required';
  END IF;
  IF length(v_tracking) > 100 OR (v_courier IS NOT NULL AND length(v_courier) > 100) THEN
    RAISE EXCEPTION 'Courier or tracking number is too long';
  END IF;

  UPDATE public.orders
  SET tracking_number = v_tracking,
      courier = COALESCE(v_courier, courier)
  WHERE id = p_order_id
  RETURNING * INTO v_order;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;
  RETURN to_jsonb(v_order);
END;
$$;

REVOKE ALL ON FUNCTION public.update_order_tracking(varchar, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_order_tracking(varchar, text, text) TO authenticated;
