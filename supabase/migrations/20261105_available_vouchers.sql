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
    AND p_subtotal >= eligible.min_purchase
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

REVOKE ALL ON FUNCTION public.list_available_vouchers(numeric)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_available_vouchers(numeric)
  TO authenticated;
