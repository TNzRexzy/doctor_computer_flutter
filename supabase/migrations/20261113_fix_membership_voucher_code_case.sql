-- Fix generated membership voucher codes to satisfy the vouchers table's
-- uppercase-only code constraint, then retry issuance for the current periods.
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

SELECT public.issue_membership_vouchers('weekly');
SELECT public.issue_membership_vouchers('monthly');
